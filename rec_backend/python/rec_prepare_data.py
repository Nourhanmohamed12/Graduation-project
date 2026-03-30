# prepare_data.py
import pickle
import numpy as np
import pandas as pd
from datetime import datetime
from typing import Dict, Tuple, List
from sklearn.model_selection import KFold
import math
from typing import Dict, Tuple, List
from scipy.stats import entropy

def smooth_time_spent(t):
    if pd.isna(t):
      return np.nan
    elif t <= 0:
      return 0
    return np.log1p(t)

def soft_quantile_scaling(scores, lower_q=0.01, upper_q=0.99):
    lower = np.quantile(scores, lower_q)
    upper = np.quantile(scores, upper_q)
    scaled = (scores - lower) / (upper - lower)
    return np.clip(scaled, 0, 1)  # mild clipping only at extremes

def create_interaction_summary(df: pd.DataFrame, weights: Dict[str, float] = None) -> pd.DataFrame:
    """Create summary of interactions between user-item pairs."""

   # Use default weights if none provided
    if weights is None:
        weights = {
            'rate': 0.35,
            'love': 0.2,
            'view': 0.25,
            'time_spent': 0.3
        }
    # Sort and group data
    df = df.sort_values('timestamp')
    grouped = df.groupby(['user_id', 'Landmark_ID'])
    summary = pd.DataFrame()

    # Process different interaction types
    summary['explicit_rating'] = grouped.apply(
        lambda x: x[x['action'] == 'rate']['rating'].iloc[-1]
        if not x[x['action'] == 'rate'].empty else np.nan
    )

    # Initialize tracking columns
    summary['views'] = 0
    summary['is_favorite'] = 0
    summary['avg_time_spent'] = 0

    # Count interactions by type
    action_counts = df.groupby(['user_id', 'Landmark_ID', 'action']).size().unstack(fill_value=0)

    # Update interaction counts
    for action, col in [('view', 'views')]:
        if action in action_counts.columns:
            summary[col] = action_counts[action]

    if 'love' in action_counts.columns:
        summary['is_favorite'] = (action_counts['love'] > 0).astype(int)

    summary['avg_time_spent'] = grouped['time_spent'].mean()
    summary['last_interaction'] = grouped['timestamp'].max()

    # We need at least one valid interaction to include in the dataset
    has_interaction = (
        pd.notna(summary['explicit_rating']) |
        pd.notna(summary['views']) |
        pd.notna(summary['is_favorite']) |
        pd.notna(summary['avg_time_spent'])
    )

    filtered_df = summary[has_interaction]
    # probable not valid data filter
    filtered_df = filtered_df[~(((filtered_df['views'] == 0) & (filtered_df['avg_time_spent'] != 0)) | ((filtered_df['views'] == 0) & (filtered_df['is_favorite'] == 1)))]

    return filtered_df.reset_index()

def calculate_interaction_score(row: pd.Series, weights: Dict[str, float]) -> float:
    """
    Calculate interaction score with favorites and views as multipliers
    """
    # Base components (additive)
    components = {}

    # Explicit rating - already on 0-1 scale
    if pd.notna(row.get('explicit_rating')):
        components['rate'] = float(row['explicit_rating']) / 5

    # Time spent
    time_score = smooth_time_spent(row.get('avg_time_spent'))
    if pd.notna(time_score):
        components['time_spent'] = time_score

    # If no base components, establish a minimal base score
    # This ensures we still capture items with only views/favorites
    if not components:
        base_score = 0.1  # Minimal base score
    else:
        # Calculate weighted average of base components
        total_weight = 0
        weighted_sum = 0

        for component_type, score in components.items():
            weighted_sum += score * weights[component_type]
            total_weight += weights[component_type]

        base_score = weighted_sum / total_weight if total_weight > 0 else 0
    #
    # Apply multipliers
    final_score = base_score

    # Favorite multiplier (30% boost)
    if pd.notna(row.get('is_favorite')) and row['is_favorite'] > 0:
        final_score = final_score * 1.3

    # Views multiplier (logarithmic scaling)
    if pd.notna(row.get('views')) and row['views'] > 0:
        view_count = float(row['views'])
        # Small boost for first view, increasing with more views
        view_multiplier = 1.0 + min(0.3, 0.1 * np.log1p(view_count))
        final_score = final_score * view_multiplier

    return final_score

def create_matrix(interaction_summary: pd.DataFrame, weights: Dict[str, float] = None) -> pd.DataFrame:
    """Create interaction matrix with normalized unified scores."""
    if weights is None:
        weights = {
            'rate': 0.35,
            'love': 0.2,
            'view': 0.25,
            'time_spent': 0.3
        }

    # Calculate scores
    interaction_summary['interaction_score'] = interaction_summary.apply(
        lambda row: calculate_interaction_score(row, weights),
        axis=1
    )

    # Remove rows with NaN scores
    interaction_summary = interaction_summary.dropna(subset=['interaction_score'])

    # Apply normalization
    interaction_summary['normalized_score'] = soft_quantile_scaling(interaction_summary['interaction_score'].values)
    # Create pivot table - NaN cells represent no interaction
    return interaction_summary.pivot(
        index='user_id',
        columns='Landmark_ID',
        values='normalized_score'
    ) 

def create_consumed_mask(df: pd.DataFrame) -> pd.DataFrame:
    """Create binary mask of consumed items."""
    consumed = df[df['action'] == 'rate'].groupby(['user_id', 'Landmark_ID']).size()
    return consumed.unstack().notna().astype(int)

def split_chronological(df: pd.DataFrame, n_train: int) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """Split each user's data chronologically."""
    train_data = pd.DataFrame()
    test_data = pd.DataFrame()

    for user_id in df['user_id'].unique():
        user_data = df[df['user_id'] == user_id].sort_values('timestamp')
        train_data = pd.concat([train_data, user_data.iloc[:n_train]])
        test_data = pd.concat([test_data, user_data.iloc[n_train:]])

    return train_data, test_data

def prepare_train_val_test_split(
    interactions_df: pd.DataFrame,
    weights: Dict[str, float] = None,
    val_ratio: float = 0.2,
    train_interactions: int = 20,
    seed: int = 42
) -> Tuple[
    Dict[str, Tuple[pd.DataFrame, pd.DataFrame]],
    Dict[str, Tuple[pd.DataFrame, pd.DataFrame]],
    pd.DataFrame,
    List[int]
]:
    """
    Prepare train/validation/test split of the data for CF, CB, and Hybrid.

    Returns:
        cf_matrices: Train/test matrices and consumed masks for Collaborative Filtering (filtered users).
        cb_matrices: Train/test matrices and consumed masks for Content-Based Filtering and Hybrid (all users).
        val_data: Validation interactions (for FWLS training).
        excluded_users: List of users excluded from CF due to sparsity.
    """

    # Step 1: Identify eligible users (enough interactions) for CF
    user_counts = interactions_df.groupby('user_id').size()
    eligible_users = user_counts[user_counts >= (train_interactions + 1)].index
    excluded_users = user_counts[user_counts < (train_interactions + 1)].index.tolist()

    # Step 2: Shuffle and split all users (no filter yet)
    all_users = interactions_df['user_id'].unique()
    rng = np.random.default_rng(seed)
    rng.shuffle(all_users)

    n_val_users = int(len(all_users) * val_ratio)
    val_users = all_users[:n_val_users]
    train_test_users = all_users[n_val_users:]

    # Step 3: Create filtered and full datasets
    filtered_df = interactions_df[interactions_df['user_id'].isin(eligible_users)]

    train_test_data_cb = interactions_df[interactions_df['user_id'].isin(train_test_users)]  # full data
    train_test_data_cf = filtered_df[filtered_df['user_id'].isin(train_test_users)]          # filtered data

    # Step 4: Chronologically split train/test for CF and CB
    train_data_cf, test_data_cf = split_chronological(train_test_data_cf, train_interactions)
    train_data_cb, test_data_cb = split_chronological(train_test_data_cb, train_interactions)

    # Step 5: Create interaction summaries
    train_summary_cf = create_interaction_summary(train_data_cf, weights)
    test_summary_cf = create_interaction_summary(test_data_cf, weights)

    train_summary_cb = create_interaction_summary(train_data_cb, weights)
    test_summary_cb = create_interaction_summary(test_data_cb, weights)

    # Step 6: Build matrices and consumed masks
    cf_matrices = {
        'train': (create_matrix(train_summary_cf, weights), create_consumed_mask(train_data_cf)),
        'test': (create_matrix(test_summary_cf, weights), create_consumed_mask(test_data_cf))
    }

    cb_matrices = {
        'train': (create_matrix(train_summary_cb, weights), create_consumed_mask(train_data_cb)),
        'test': (create_matrix(test_summary_cb, weights), create_consumed_mask(test_data_cb))
    }

    # Step 7: Validation data (for FWLS meta-model fitting)
    val_data = interactions_df[interactions_df['user_id'].isin(val_users)]

    return cf_matrices, cb_matrices, val_data, excluded_users

def prepare_cv_folds(
    val_data: pd.DataFrame,
    weights: Dict[str, float] = None,
    train_interactions: int = 30,
    n_folds: int = 2,
) -> Dict[int, Dict[str, Tuple[pd.DataFrame, pd.DataFrame]]]:
    """Prepare cross-validation folds from validation data."""
    users = val_data['user_id'].unique()
    cv_folds = {}

    kf = KFold(n_splits=n_folds, shuffle=True, random_state=42)

    for fold_idx, (train_idx, val_idx) in enumerate(kf.split(users)):
        train_users, val_users = users[train_idx], users[val_idx]

        fold_train_data = val_data[val_data['user_id'].isin(train_users)]
        fold_val_data = val_data[val_data['user_id'].isin(val_users)]

        val_train_data, val_test_data = split_chronological(fold_val_data, train_interactions)

        val_train_summary = create_interaction_summary(val_train_data, weights)
        val_test_summary = create_interaction_summary(val_test_data, weights)

        cv_folds[fold_idx] = {
            'train': (
                create_matrix(val_train_summary, weights),
                create_consumed_mask(val_train_data)
            ),
            'val': (
                create_matrix(val_test_summary, weights),
                create_consumed_mask(val_test_data)
            )
        }

    return cv_folds

def get_top_n_popular_items_by_avg_score(summary_df, n=10):
    avg_scores = summary_df.groupby('Landmark_ID')['explicit_rating'].mean()
    sorted_items = avg_scores.sort_values(ascending=False)
    return list(sorted_items.head(n).items())

def calculate_meta_features(
    train_matrix: pd.DataFrame,
    interaction_df: pd.DataFrame,
    interaction_threshold: int = 10
) -> pd.DataFrame:
    """
    Calculate meta-features for FWLS hybrid recommender system

    Args:
        train_matrix: User-item interaction matrix
        interaction_df: Original interaction dataframe
        interaction_threshold: Minimum interactions to not be considered a cold user

    Returns:
        DataFrame with user_id, item_id and meta-features
    """
    # Get all unique users and items
    all_users = train_matrix.index.tolist()
    all_items = train_matrix.columns.tolist()

    meta_features = []

    # 1. Calculate user interaction counts (for binary cold-start feature)
    user_interaction_counts = train_matrix.notna().sum(axis=1)

    # 2. Calculate item popularity
    item_popularity = train_matrix.notna().sum(axis=0)
    max_popularity = item_popularity.max()
    normalized_popularity = item_popularity / max_popularity if max_popularity > 0 else item_popularity

    # 3. Calculate user entropy (for each user)
    user_entropy = {}
    for user_id in all_users:
        user_ratings = train_matrix.loc[user_id].dropna()
        if len(user_ratings) > 1:  # Need at least 2 ratings to calculate meaningful entropy
            # Normalize ratings to form a probability distribution
            probs = user_ratings / user_ratings.sum()
            user_entropy[user_id] = entropy(probs)
        else:
            user_entropy[user_id] = 0  # Default for users with 0-1 interactions

    # Create meta-features for all user-item pairs
    for user_id in all_users:
        for item_id in all_items:
            # Binary cold-start feature
            is_cold_user = 1 if user_interaction_counts[user_id] <= interaction_threshold else 0

            meta_features.append({
                'user_id': user_id,
                'item_id': item_id,
                'cold_user': is_cold_user,
                'user_entropy': user_entropy[user_id],
                'item_popularity': normalized_popularity[item_id]
            })

    return pd.DataFrame(meta_features)

def main():

    # Load interaction CSV
    interaction_df = pd.read_csv(r'/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/rec_data/interactions.csv')

    # Create summary and full matrix
    summary_df = create_interaction_summary(interaction_df)

    # Prepare train/test matrices and validation folds
    cf_matrices, cb_matrices, val_data, excluded_users = prepare_train_val_test_split(interaction_df)
    cv_folds_dict = prepare_cv_folds(val_data)

    # Convert validation folds to list of tuples for cross-validation
    cv_folds = []
    cv_masks = []
    for fold_idx, fold in cv_folds_dict.items():
        train_matrix_df = pd.DataFrame(fold['train'][0]).astype(np.float32)
        val_matrix_df = pd.DataFrame(fold['val'][0]).astype(np.float32)

        try:
            train_mask_df = pd.DataFrame(fold['train'][1]).astype(int)
            val_mask_df = pd.DataFrame(fold['val'][1]).astype(int)
        except (ValueError, TypeError):
            print(f"Warning (fold {fold_idx}): mask conversion issue")
            train_mask_df = pd.DataFrame(fold['train'][1])
            val_mask_df = pd.DataFrame(fold['val'][1])

        cv_folds.append((train_matrix_df, val_matrix_df))
        cv_masks.append((train_mask_df, val_mask_df))

    # Get top popular items
    top_popular = get_top_n_popular_items_by_avg_score(summary_df)

    # Calculate meta-features (using CB train matrix)
    cb_train_matrix = cb_matrices['train'][0]
    meta_features_df = calculate_meta_features(cb_train_matrix, interaction_df, interaction_threshold=5)

    # Save everything to be used by training and recommend scripts
    with open(r"/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/models/prepared_data.pkl", "wb") as f:
        pickle.dump({
            "cf_matrices": cf_matrices,
            "cb_matrices": cb_matrices,
            "cv_folds": cv_folds,
            "cv_masks": cv_masks,
            "meta_features": meta_features_df,
            "top_popular": top_popular
        }, f)

    print("Data preparation complete. Saved to 'prepared_data.pkl'.")

if __name__ == "__main__":
    main()
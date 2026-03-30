import numpy as np
import pandas as pd
from typing import Tuple, List, Dict
from sklearn.metrics import mean_squared_error,mean_absolute_error
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from sklearn.decomposition import PCA
import re
import nltk
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
# nltk.download('wordnet')
# nltk.download('stopwords')
# nltk.download('punkt')
# nltk.download('punkt_tab')
from nltk.stem import WordNetLemmatizer
from sklearn.decomposition import NMF
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.linear_model import LinearRegression
import logging
from sklearn.metrics import mean_squared_error
import pickle
import warnings
warnings.filterwarnings('ignore')


class CollaborativeFilteringRecommender:
    """
    A collaborative filtering recommender system based on matrix factorization.
    Supports training, prediction, recommendation generation, and evaluation.
    """

    def __init__(self, n_factors: int = 5, n_epochs: int = 100,
                 learning_rate: float = 0.005, reg: float = 0.02, test_matrix = None, consumed_mask = None):
        """
        Initialize the recommender system with hyperparameters.

        Args:
            n_factors: Number of latent factors
            n_epochs: Number of training epochs
            learning_rate: Learning rate for SGD
            reg: Regularization strength
        """
        self.n_factors = n_factors
        self.n_epochs = n_epochs
        self.learning_rate = learning_rate
        self.reg = reg

        # Model parameters (initialized during training)
        self.user_factors = None
        self.item_factors = None
        self.user_biases = None
        self.item_biases = None
        self.global_bias = None
        self.train_matrix = None
        self.training_errors = None
        # For mapping between IDs and indices
        self.user_indices = {}  # Map user_id -> index
        self.item_indices = {}  # Map item_id -> index
        self.users = []         # List of user_ids in original format
        self.items = []         # List of item_ids in original format

        self.consumed_mask = consumed_mask
        self.test_matrix = test_matrix

    def initialize_parameters(self, n_users: int, n_items: int,
                              ratings_matrix: pd.DataFrame = None) -> None:
        """
        Initialize model parameters with proper global bias calculation.

        Args:
            n_users: Number of users
            n_items: Number of items
            ratings_matrix: Matrix of user-item ratings
        """
        if self.n_factors is None:
            self.n_factors = min(10, n_users / 2, n_items / 2)

        # Random initialization of factors and biases
        self.user_factors = np.random.normal(0, 0.1, (n_users, self.n_factors))
        self.item_factors = np.random.normal(0, 0.1, (n_items, self.n_factors))
        self.user_biases = np.zeros(n_users)
        self.item_biases = np.zeros(n_items)
        self.global_bias = np.nanmean(ratings_matrix.values) if ratings_matrix is not None else 0

    def predict_rating(self, user_idx: int, item_idx: int,
                      min_score: float = 0, max_score: float = 1) -> float:
        """
        Predict rating for a single user-item pair.

        Args:
            user_idx: User index
            item_idx: Item index
            min_score: Minimum possible score
            max_score: Maximum possible score

        Returns:
            Predicted rating
        """
        # Calculate prediction using matrix factorization formulauser_indices
        pred = (
            self.global_bias +
            self.user_biases[user_idx] +
            self.item_biases[item_idx] +
            self.user_factors[user_idx] @ self.item_factors[item_idx]
        )
        return np.clip(pred, min_score, max_score)

    def update_parameters(self, user_idx: int, item_idx: int, error: float) -> None:
        """
        Update model parameters using gradient descent.

        Args:
            user_idx: User index
            item_idx: Item index
            error: Prediction error
        """
        # Update biases with regularization
        self.user_biases[user_idx] += self.learning_rate * (error - self.reg * self.user_biases[user_idx])
        self.item_biases[item_idx] += self.learning_rate * (error - self.reg * self.item_biases[item_idx])

        # Update latent factors
        user_factors_prev = self.user_factors[user_idx].copy()
        self.user_factors[user_idx] += self.learning_rate * (error * self.item_factors[item_idx] - self.reg * self.user_factors[user_idx])
        self.item_factors[item_idx] += self.learning_rate * (error * user_factors_prev - self.reg * self.item_factors[item_idx])

    def fit(self, ratings: pd.DataFrame, verbose: bool = False) -> List[float]:
        """
        Train matrix factorization model using SGD.

        Args:
            ratings: DataFrame with user-item ratings
            verbose: Whether to print progress

        Returns:
            List of training errors
        """
        # Save the training matrix for future reference
        self.train_matrix = ratings

        # Extract unique users and items, preserving their original format
        # IMPORTANT: Convert all IDs to strings to ensure consistent handling
        self.users = [str(user_id) for user_id in ratings.index]
        self.items = [str(item_id) for item_id in ratings.columns]

        # Create simple index mappings (now using string IDs)
        self.user_indices = {str(user_id): idx for idx, user_id in enumerate(self.users)}
        self.item_indices = {str(item_id): idx for idx, item_id in enumerate(self.items)}

        # Setup initial parameters
        ratings_matrix = ratings.values
        n_users, n_items = ratings_matrix.shape
        self.initialize_parameters(n_users, n_items, ratings)

        # Training loop
        self.training_errors = []
        for epoch in range(self.n_epochs):
            # Get non-null ratings
            users, items = np.where(~np.isnan(ratings_matrix))
            indices = np.arange(len(users))
            np.random.shuffle(indices)

            # Process each rating
            epoch_error = 0
            for idx in indices:
                u, i = users[idx], items[idx]
                actual = ratings_matrix[u, i]
                pred = self.predict_rating(u, i)
                error = actual - pred

                # Update model parameters
                self.update_parameters(u, i, error)
                epoch_error += error ** 2

            # Calculate and store RMSE
            rmse = np.sqrt(epoch_error / len(users))
            self.training_errors.append(rmse)

            if verbose and (epoch + 1) % 5 == 0:
                print(f"Epoch {epoch + 1}/{self.n_epochs}, RMSE: {rmse:.4f}")

        return self.training_errors
    def get_recommendations(self, user_id, current_item_id=None, n_items: int = 10, consumed_mask: pd.DataFrame = None) -> Tuple[List, np.ndarray]:
        """
        Get top-N recommendations for a user based on predicted ratings.

        Args:
            user_id: User ID to get recommendations for (can be any format)
            current_item_id: Current item ID to exclude from recommendations
            n_items: Number of recommendations to generate
            consumed_mask: Mask indicating which items have been consumed

        Returns:
            Tuple of (recommended item IDs, predicted scores)
        """
        # Convert IDs to strings to ensure consistent lookup
        user_id_str = str(user_id)
        current_item_id_str = str(current_item_id) if current_item_id is not None else None

        # Direct lookup with string user ID format
        if user_id_str not in self.user_indices:
            return [], np.array([])

        user_pos = self.user_indices[user_id_str]

        # Get all possible items
        all_items = self.items

        # Filter out already consumed items if mask is provided
        unavailable_items = []
        if consumed_mask is not None and user_id in consumed_mask.index:
            unavailable_items = [str(item) for item in consumed_mask.columns[consumed_mask.loc[user_id] == 1].tolist()]

        # Filter out current item
        if current_item_id_str in all_items and current_item_id_str not in unavailable_items:
            unavailable_items.append(current_item_id_str)

        # Calculate predictions for all unconsumed items
        predictions = []
        for item_id in all_items:
            if item_id not in unavailable_items and item_id in self.item_indices:
                item_pos = self.item_indices[item_id]
                pred = self.predict_rating(user_pos, item_pos)
                predictions.append((item_id, pred))

        # If no predictions returned
        if not predictions:
            return [], np.array([])

        # Sort by predicted rating and return top-N
        predictions.sort(key=lambda x: x[1], reverse=True)
        top_items = [item_id for item_id, _ in predictions[:n_items]]
        top_scores = np.array([score for _, score in predictions[:n_items]])

        return top_items, top_scores

    def evaluate(self, test_matrix: pd.DataFrame, consumed_mask: pd.DataFrame = None,
                n_items: int = 10, k_values: List[int] = [5, 7, 10]) -> Dict:
        """
        Evaluate model with various recommendation metrics.

        Args:
            test_matrix: Test data matrix
            consumed_mask: Mask of consumed items
            n_items: Max number of items to recommend
            k_values: List of k values for evaluation metrics

        Returns:
            Dictionary of evaluation metrics
        """
        # Fix: Use proper None checks instead of 'or' operator
        if test_matrix is None:
            test_matrix = self.test_matrix
        if consumed_mask is None:
            consumed_mask = self.consumed_mask

        results = {
            'rmse': 0.0,
            'precision': {k: [] for k in k_values},
            'recall': {k: [] for k in k_values},
            'hit_rate': {k: [] for k in k_values},
            'average_precision': [],
            'ndcg': {k: [] for k in k_values},
            'reciprocal_ranks': []
        }

        # Find common users between train and test sets
        common_users = list(set(self.train_matrix.index) & set(test_matrix.index))

        # Calculate RMSE on test set
        all_preds = []
        all_actuals = []

        for user_id in common_users:
            user_id_str = str(user_id)
            if user_id_str not in self.user_indices:
                continue

            user_pos = self.user_indices[user_id_str]
            test_ratings = test_matrix.loc[user_id].dropna()

            for item_id, actual in test_ratings.items():
                item_id_str = str(item_id)
                if item_id_str in self.item_indices:
                    item_pos = self.item_indices[item_id_str]
                    pred = self.predict_rating(user_pos, item_pos)
                    all_preds.append(pred)
                    all_actuals.append(actual)

        # Calculate RMSE if we have predictions
        if all_preds:
            results['rmse'] = np.sqrt(mean_squared_error(all_actuals, all_preds))

        # Calculate recommendation metrics for each user
        for user_id in common_users:
            # Get the user's recommendations
            recs, _ = self.get_recommendations(
                user_id=user_id,
                n_items=max(k_values),
                consumed_mask=consumed_mask
            )

            # Get the user's actual test items
            relevant_items = test_matrix.loc[user_id].dropna().index.tolist()
            relevant_items_str = [str(item) for item in relevant_items]

            if not relevant_items:
                continue  # Skip users with no test items

            # Calculate average precision
            ap = 0.0
            hits = 0
            for i, item in enumerate(recs):
                if item in relevant_items_str:
                    hits += 1
                    ap += hits / (i + 1)

            ap = ap / len(relevant_items) if len(relevant_items) > 0 else 0
            results['average_precision'].append(ap)

            rr = 0.0
            for rank, item in enumerate(recs, start=1):
                if item in relevant_items_str:
                    rr = 1.0 / rank
                    break
            results['reciprocal_ranks'].append(rr)

            # Calculate precision and recall at different k values
            for k in k_values:
                if k <= len(recs):
                    recs_at_k = recs[:k]
                    hits_at_k = len(set(recs_at_k) & set(relevant_items_str))

                    # Precision@k and Recall@k
                    precision_k = hits_at_k / k
                    recall_k = hits_at_k / len(relevant_items) if len(relevant_items) > 0 else 0

                    gains = [1 if item in relevant_items_str else 0 for item in recs_at_k]
                    dcg = sum(gain / np.log2(i + 2) for i, gain in enumerate(gains))

                    ideal_gains = [1] * min(len(relevant_items), k)
                    idcg = sum(g / np.log2(i + 2) for i, g in enumerate(ideal_gains))

                    ndcg_k = dcg / idcg if idcg > 0 else 0.0

                    results['ndcg'][k].append(ndcg_k)
                    results['precision'][k].append(precision_k)
                    results['recall'][k].append(recall_k)
                    results['hit_rate'][k].append(1.0 if hits_at_k > 0 else 0.0)

        # Average the results
        results['map'] = np.mean(results['average_precision']) if results['average_precision'] else 0.0
        results['mrr'] = np.mean(results['reciprocal_ranks']) if results['reciprocal_ranks'] else 0.0

        for k in k_values:
            for metric in ['precision', 'recall', 'hit_rate']:
                values = results[metric][k]
                results[metric][k] = np.mean(values) if values else 0.0

                # Average NDCG
                ndcg_vals = results['ndcg'][k]
                results['ndcg'][k] = np.mean(ndcg_vals) if ndcg_vals else 0.0

        # Add coverage of test set
        results['user_coverage'] = len([u for u in common_users if test_matrix.loc[u].dropna().size > 0]) / len(common_users) if common_users else 0

        return results

    # Visualization methods
    def plot_training_progress(self):
        """Plot the training error over epochs."""
        plt.figure(figsize=(10, 5))
        plt.plot(range(1, len(self.training_errors) + 1), self.training_errors, 'b-', marker='o')
        plt.title('Training Progress')
        plt.xlabel('Epoch')
        plt.ylabel('RMSE')
        plt.grid(True)
        plt.tight_layout()
        plt.show()

    def plot_metric_comparison(self, results: Dict, k_values: List[int] = [5, 10, 20]):
        """Plot precision, recall and hit rate at different k values."""
        metrics = ['precision', 'recall', 'hit_rate']

        plt.figure(figsize=(12, 6))

        x = np.arange(len(k_values))
        width = 0.25

        for i, metric in enumerate(metrics):
            values = [results[metric][k] for k in k_values]
            plt.bar(x + (i-1)*width, values, width, label=metric.capitalize())

        plt.xlabel('k value')
        plt.ylabel('Score')
        plt.title('Recommendation Performance Metrics')
        plt.xticks(x, k_values)
        plt.legend()
        plt.grid(True, axis='y')
        plt.tight_layout()
        plt.show()

    def plot_precision_recall_ndcg_curves(self, results: Dict, k_values: List[int]):
        """Plot precision, recall and NDCG curves at different k values."""
        metrics = ['precision', 'recall', 'ndcg']
        plt.figure(figsize=(12, 6))

        for metric in metrics:
            values = [results[metric][k] for k in k_values]
            plt.plot(k_values, values, marker='o', label=metric.upper())

        plt.xlabel('k')
        plt.ylabel('Score')
        plt.title('Evaluation Metrics by k')
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plt.show()

    def plot_overall_metrics(self, map_val, mrr_val, coverage_val):
        """Plot overall metrics like MAP, MRR, and User Coverage."""
        metrics = ['MAP', 'MRR', 'User Coverage']
        values = [map_val, mrr_val, coverage_val]

        plt.figure(figsize=(8, 5))
        sns.barplot(x=metrics, y=values, palette='coolwarm')
        plt.title("Overall Evaluation Metrics")
        plt.ylim(0, 1.05)
        plt.grid(True, axis='y')
        plt.tight_layout()
        plt.show()

    def plot_scoring_distribution(self, matrix: pd.DataFrame, title: str = "Rating Distribution"):
        """Plot the distribution of ratings in the matrix."""
        # Get non-null ratings
        ratings = matrix.values[~np.isnan(matrix.values)]

        plt.figure(figsize=(10, 5))
        plt.hist(ratings, bins=20, color='blue', alpha=0.7)
        plt.title(title)
        plt.xlabel('Rating Value')
        plt.ylabel('Count')
        plt.grid(True)
        plt.tight_layout()
        plt.show()

    def plot_user_item_interactions(self, matrix, sample_size=50):
        """Plot a heatmap of user-item interactions for a sample of users and items."""
        # Sample users and items if the matrix is large
        if matrix.shape[0] > sample_size:
            users_sample = np.random.choice(matrix.index, sample_size, replace=False)
            sample_matrix = matrix.loc[users_sample]
        else:
            sample_matrix = matrix

        if sample_matrix.shape[1] > sample_size:
            items_sample = np.random.choice(sample_matrix.columns, sample_size, replace=False)
            sample_matrix = sample_matrix[items_sample]

        plt.figure(figsize=(12, 10))
        sns.heatmap(sample_matrix, cmap='viridis', cbar_kws={'label': 'Rating Value'})
        plt.title('User-Item Interaction Heatmap (Sample)')
        plt.xlabel('Items')
        plt.ylabel('Users')
        plt.show()
###################################################################################################################################################################################################################################


np.set_printoptions(precision=6, suppress=True)
class NMFContentRecommender_merged:
    def __init__(self, num_topics):
        self.num_topics = num_topics
        self.item_topic_matrix = None
        self.items_df = None
        self.user_profiles = None
        self.lemmatizer = WordNetLemmatizer()
        self.tfidf_vectorizer = None
        self.nmf_model = None
        self.scores_df = None
        self.stop_words = set(stopwords.words('english'))

    def preprocess_text(self, text):
        # Lowercase and remove non-alphabetic characters
        text = re.sub(r'[^a-zA-Z]', ' ', text.lower())
        tokens = nltk.word_tokenize(text)
        tokens = [self.lemmatizer.lemmatize(token) for token in tokens if token not in self.stop_words and len(token) > 1]
        return " ".join(tokens)

    def prepare_corpus(self, items_df):
        self.items_df = items_df.copy()
        items_df['text_features'] = items_df['name'] + ' ' + items_df['description'] + ' ' + \
                                    items_df['category'] + ' ' + items_df['city']
        items_df['processed_text'] = items_df['text_features'].apply(self.preprocess_text)

        self.tfidf_vectorizer = TfidfVectorizer(max_features=1000)
        tfidf_matrix = self.tfidf_vectorizer.fit_transform(items_df['processed_text'])
        return tfidf_matrix

    def train_nmf_model(self, tfidf_matrix):
        self.nmf_model = NMF(n_components=self.num_topics, random_state=42)
        self.item_topic_matrix = self.nmf_model.fit_transform(tfidf_matrix)

    def add_weighted_item_topics_to_user_profile(self, train_matrix):
        item_ids = train_matrix.columns
        self.items_df = self.items_df.set_index("Landmark_ID")
        matched_indices = [self.items_df.index.get_loc(item_id) if item_id in self.items_df.index else None for item_id in item_ids]
        valid_indices = [idx for idx in matched_indices if idx is not None]

        if len(valid_indices) == 0:
            raise ValueError("No items in train_matrix match items in items_df.")

        filtered_item_topic_matrix = pd.DataFrame(self.item_topic_matrix).iloc[valid_indices]
        matched_train_matrix = train_matrix.loc[:, [item_id for item_id, idx in zip(item_ids, matched_indices) if idx is not None]]
        user_topic_matrix = np.dot(matched_train_matrix.fillna(0).values, filtered_item_topic_matrix.values)
        user_topic_matrix /= user_topic_matrix.sum(axis=1, keepdims=True)
        self.user_profiles = {str(user_id): user_topic_matrix[idx] for idx, user_id in enumerate(train_matrix.index)}

        user_topic_df = pd.DataFrame(user_topic_matrix,
                                     index=train_matrix.index,
                                     columns=[f"Topic_{i}" for i in range(filtered_item_topic_matrix.shape[1])])

        self.items_df = self.items_df.reset_index()
        return user_topic_df

    def get_item_recommendations(self, item_id, n_recommendations=5):
        item_idx = self.items_df[self.items_df['Landmark_ID'] == item_id].index[0]
        item_topics = self.item_topic_matrix[item_idx]
        similarities = cosine_similarity([item_topics], self.item_topic_matrix)[0]

        # Get all indices except the current item
        all_indices = np.argsort(similarities)[::-1]
        all_indices = [i for i in all_indices if i != item_idx]
        top_indices = all_indices[:n_recommendations]

        recommendations = self.items_df.iloc[top_indices][['Landmark_ID', 'name', 'category', 'city']].copy()
        recommendations['similarity_score'] = similarities[top_indices]
        return recommendations

    def get_user_recommendations(self, user_id, n_recommendations=5):
        if str(user_id) not in self.user_profiles:
            return pd.DataFrame(columns=['Landmark_ID', 'name', 'category', 'city', 'similarity_score'])

        user_profile = self.user_profiles[str(user_id)]
        similarities = cosine_similarity([user_profile], self.item_topic_matrix)[0]
        similar_indices = similarities.argsort()[::-1]

        recommendations = self.items_df.iloc[similar_indices][['Landmark_ID', 'name', 'category', 'city']].copy()
        recommendations['similarity_score'] = similarities[similar_indices]
        return recommendations.head(n_recommendations)

    def get_combined_top_recommendations(self, item_id, user_id, top_n=5):
        item_idx = self.items_df[self.items_df['Landmark_ID'] == item_id].index[0]

        item_recs = self.get_item_recommendations(item_id, n_recommendations=top_n * 2)
        user_recs = self.get_user_recommendations(str(user_id), n_recommendations=top_n * 2)

        combined = pd.concat([item_recs, user_recs])
        combined = combined.sort_values(by='similarity_score', ascending=False)
        combined = combined[combined['Landmark_ID'] != self.items_df.iloc[item_idx]['Landmark_ID']]
        combined = combined.drop_duplicates(subset='Landmark_ID')

        return combined.head(top_n)

    def _predict_raw_user_item_score(self, user_id, item_id, train_matrix):
        """
        Predicts a numerical rating for a user on a specific item,using a weighted average.
        This version returns the RAW prediction, without clipping or normalization.
        """
        user_ratings_data = train_matrix.copy() # Store for later use in prediction
        user_ratings_data.index = user_ratings_data.index.astype(str)
        user_id = str(user_id)

        if user_id not in user_ratings_data.index:
            return np.nan

        user_rated_items = user_ratings_data.loc[user_id].dropna()
        if user_rated_items.empty:
            return np.nan

        user_rated_items = user_rated_items.drop(labels=[item_id], errors='ignore')

        if user_rated_items.empty:
            return np.nan

        user_mean_rating = user_rated_items.mean()

        if self.items_df.index.name == 'Landmark_ID':
            self.items_df = self.items_df.reset_index()

        target_item_row = self.items_df[self.items_df['Landmark_ID'] == item_id]
        if target_item_row.empty:
            return np.nan

        target_item_idx = target_item_row.index[0]
        item_topic_to_predict = self.item_topic_matrix[target_item_idx]

        pre = 0.0
        sim_sum = 0.0

        rated_item_ids_list = user_rated_items.index.tolist()
        rated_item_indices_in_full_matrix = [
            self.items_df[self.items_df['Landmark_ID'] == rid].index[0]
            for rid in rated_item_ids_list if rid in self.items_df['Landmark_ID'].values
        ]

        if not rated_item_indices_in_full_matrix:
            return user_mean_rating

        rated_item_topic_vectors = self.item_topic_matrix[rated_item_indices_in_full_matrix]
        similarities = cosine_similarity([item_topic_to_predict], rated_item_topic_vectors)[0]

        for i, sim_val in enumerate(similarities):
            rated_item_id = rated_item_ids_list[i]
            r = user_rated_items.loc[rated_item_id] - user_mean_rating
            pre += sim_val * r
            sim_sum += abs(sim_val)

        if sim_sum > 0:
            raw_prediction = user_mean_rating + pre / sim_sum
        else:
            raw_prediction = user_mean_rating

        return raw_prediction


    def generate_and_normalize_all_predictions(self, train_matrix, all_items_df):
        """
        Generates predicted ratings for all user-item pairs not in train_matrix,
        and then normalizes them between 0 and 1 based on the min/max of all generated predictions.

        Args:
            train_matrix (pd.DataFrame): User-item rating matrix.
            all_items_df (pd.DataFrame): DataFrame containing all items with 'Landmark_ID'.

        Returns:
            pd.DataFrame: A DataFrame with 'user_id', 'item_id', 'predicted_rating' (normalized).
        """
        raw_predictions = []
        all_item_ids = all_items_df['Landmark_ID'].unique()

        # Ensure items_df in recommender is not indexed by Landmark_ID for consistent lookups
        if self.items_df.index.name == 'Landmark_ID':
            self.items_df = self.items_df.reset_index()

        for user_id in train_matrix.index:
            rated_items_by_user = train_matrix.loc[user_id].dropna().index.tolist()

            for item_id in all_item_ids:
                if item_id in rated_items_by_user: # Predict only for UNRATED items
                    raw_score = self._predict_raw_user_item_score(user_id, item_id, train_matrix)
                    if not np.isnan(raw_score):
                        raw_predictions.append({'user_id': user_id, 'item_id': item_id, 'predicted_rating': raw_score})

        if not raw_predictions:
            return pd.DataFrame(columns=['user_id', 'item_id', 'predicted_rating'])

        predictions_df = pd.DataFrame(raw_predictions)

        # Apply min-max normalization across all predicted ratings
        min_pred = predictions_df['predicted_rating'].min()
        max_pred = predictions_df['predicted_rating'].max()

        if max_pred == min_pred:
            predictions_df['predicted_rating'] = 0.5 # All predictions are the same
        else:
            predictions_df['predicted_rating'] = (predictions_df['predicted_rating'] - min_pred) / (max_pred - min_pred)

        return predictions_df


    def plot_predicted_ratings_distribution(self, predictions_df):
        """
        Draws a histogram of the predicted ratings.
        """
        if predictions_df.empty:
            print("No predictions to plot for distribution.")
            return

        plt.figure(figsize=(10, 6))
        sns.histplot(predictions_df['predicted_rating'], kde=True, bins=20)
        plt.title('Distribution of Normalized Predicted Ratings (0-1)')
        plt.xlabel('Normalized Predicted Rating (0-1)')
        plt.ylabel('Frequency')
        plt.grid(axis='y', linestyle='--', alpha=0.7)
        plt.tight_layout()
        plt.show()

    def plot_predicted_ratings_qq_plot(self, predictions_df):
        """
        Draws a Q-Q plot of the predicted ratings against a normal distribution.
        """
        if predictions_df.empty:
            print("No predictions to plot for Q-Q graph.")
            return

        plt.figure(figsize=(8, 8))
        stats.probplot(predictions_df['predicted_rating'], dist="norm", plot=plt)
        plt.title('Q-Q Plot of Normalized Predicted Ratings (vs. Normal Distribution)')
        plt.xlabel('Theoretical Quantiles (Normal Distribution)')
        plt.ylabel('Sample Quantiles (Normalized Predicted Ratings)')
        plt.grid(True, linestyle='--', alpha=0.7)
        plt.tight_layout()
        plt.show()


    def evaluate_model(self, test_matrix, top_n_recs=10):
        precisions = []
        recalls = []
        # Store MAE/RMSE for rating prediction evaluation
        actual_ratings = []
        predicted_ratings = []

        for user_id in test_matrix.index:
            # --- Top-N Recommendation Evaluation ---
            actual_items = set(test_matrix.loc[user_id].dropna().index)
            # Use get_user_recommendations for top-N
            recommended_df = self.get_user_recommendations(str(user_id), n_recommendations=top_n_recs)
            recommended_items = set(recommended_df['Landmark_ID'])

            if len(recommended_items) > 0 and len(actual_items) > 0: # Ensure no division by zero
                precision = len(actual_items & recommended_items) / len(recommended_items)
                recall = len(actual_items & recommended_items) / len(actual_items)
                precisions.append(precision)
                recalls.append(recall)

            # --- Rating Prediction Evaluation ---
            for item_id, actual_rating in test_matrix.loc[user_id].dropna().items():
                predicted_rating = self._predict_raw_user_item_score(user_id, item_id, test_matrix)
                if not np.isnan(predicted_rating):
                    actual_ratings.append(actual_rating)
                    predicted_ratings.append(predicted_rating)

        mean_precision = np.mean(precisions) if precisions else 0
        mean_recall = np.mean(recalls) if recalls else 0
        mean_f1 = 0
        if mean_precision + mean_recall > 0:
            mean_f1 = 2 * mean_precision * mean_recall / (mean_precision + mean_recall)

        rmse = 0
        mae = 0
        if actual_ratings and predicted_ratings:
            rmse = np.sqrt(np.mean((np.array(actual_ratings) - np.array(predicted_ratings))**2))
            mae = np.mean(np.abs(np.array(actual_ratings) - np.array(predicted_ratings)))

        return {
            'mean_precision': mean_precision,
            'mean_recall': mean_recall,
            'mean_f1': mean_f1,
            'rmse': rmse,
            'mae': mae
        }
###########################################################################################################################################################################

class FWLSHybridRecommender:
    def __init__(self, cf_model, cb_model, train_matrix,train_mask, meta_features_df,
                 test_matrix=None, test_mask=None, top_popular_items=None, top_n=10):
        self.cf_model = cf_model
        self.cb_model = cb_model
        self.train_matrix = train_matrix
        self.meta_features_df = meta_features_df
        self.test_matrix = test_matrix
        self.test_mask = test_mask
        self.train_mask = train_mask
        self.data_df = None
        self.top_popular_items = top_popular_items or []
        self.top_n = top_n
        self.current_candidates = set()

        self.meta_regressor = LinearRegression()

        self.logger = logging.getLogger("FWLSHybrid")
        handler = logging.StreamHandler()
        formatter = logging.Formatter('%(levelname)s:%(name)s:%(message)s')
        handler.setFormatter(formatter)
        if not self.logger.handlers:
            self.logger.addHandler(handler)
        self.logger.setLevel(logging.INFO)

    def _prepare_training_data(self):
        df = self.meta_features_df.copy()
        matrix_dict = {
            (user, item): self.train_matrix.loc[user, item]
            for user in self.train_matrix.index
            for item in self.train_matrix.columns
            if not pd.isna(self.train_matrix.loc[user, item]) and self.train_matrix.loc[user, item] > 0
        }

        data = []
        for _, row in df.iterrows():
            user_id, item_id = row['user_id'], row['item_id']
            true_score = matrix_dict.get((user_id, item_id), np.nan)
            if pd.isna(true_score):
                continue

            try:
                cf_score = self.cf_model.predict_rating(
                self.cf_model.user_indices[str(user_id)],
                self.cf_model.item_indices[str(item_id)],
                min_score=0, max_score=1
                )
            except Exception:
                cf_score = np.nan

            try:
                cb_score = self.cb_model._predict_raw_user_item_score(str(user_id), item_id, self.train_matrix)
            except Exception:
                cb_score = np.nan

            row_data = row.to_dict()
            row_data.update({
                'true_score': true_score,
                'cf_score': cf_score,
                'cb_score': cb_score
            })
            data.append(row_data)
        train_df = pd.DataFrame(data)
        train_df['user_id'] = train_df['user_id'].astype(str)
        self.data_df = train_df.copy()
        return train_df

    def fit(self):
        self.logger.info("Training FWLS hybrid model with interaction terms")
        df = self._prepare_training_data()

        if df.empty:
            self.logger.warning("Training data is empty")
            return False

        df['cf_score'] = df['cf_score'].fillna(0)
        df['cb_score'] = df['cb_score'].fillna(0)

        meta_feature_cols = [col for col in df.columns if col not in [
            'user_id', 'item_id', 'true_score', 'cf_score', 'cb_score'
        ]]

        # Build interaction features: f_k * r_cf and f_k * r_cb
        interaction_features = {}

        for col in meta_feature_cols:
            interaction_features[f"{col}_cf"] = df[col] * df['cf_score']
            interaction_features[f"{col}_cb"] = df[col] * df['cb_score']

        X = pd.DataFrame(interaction_features)
        y = df['true_score']

        self.meta_regressor = LinearRegression()
        self.meta_regressor.fit(X, y)

        self.logger.info("FWLS training completed with %d features", len(X.columns))
        return True

    def predict(self, user_id, item_id):
        """
        Predict the score for a given user-item pair using interaction-based FWLS.
        
        Args:
            user_id (str): User identifier
            item_id (str): Item identifier
        
        Returns:
            float: Predicted score or 0.0 if unavailable
        """
        self.meta_features_df['user_id'] = self.meta_features_df['user_id'].astype(str)

        row = self.meta_features_df[
            (self.meta_features_df['user_id'] == str(user_id)) & 
            (self.meta_features_df['item_id'] == item_id)
        ]

        if item_id not in self.current_candidates or row.empty:
            return 0.0

        # Extract meta-features
        meta_feature_cols = [
            col for col in self.meta_features_df.columns 
            if col not in ['user_id', 'item_id']
        ]
        
        try:
            meta_features = row[meta_feature_cols].values[0]
        except IndexError:
            return 0.0

        # Get CF prediction
        try:
            cf_pred = self.cf_model.predict_rating(
                self.cf_model.user_indices[str(user_id)],
                self.cf_model.item_indices[str(item_id)],
                min_score=0, max_score=1
            )
            if np.isnan(cf_pred):
              cf_pred = 0.0
        except (KeyError, Exception):
            cf_pred = 0.0

        # Get CB prediction
        try:
            cb_pred = self.cb_model._predict_raw_user_item_score(user_id, item_id, self.train_matrix)
            if np.isnan(cb_pred):
              cf_pred = 0.0
        except Exception:
            cb_pred = 0.0

        # If both are zero, fallback
        if cf_pred == 0.0 and cb_pred == 0.0:
            return 0.0

        # Build 6-feature vector: [f1*r_cf, f2*r_cf, ..., f1*r_cb, f2*r_cb, ...]
        interaction_features = []
        for f in meta_features:
            interaction_features.append(f * cf_pred)
        for f in meta_features:
            interaction_features.append(f * cb_pred)

        try:
            final_score = self.meta_regressor.predict([interaction_features])[0]
        except Exception:
            final_score = 0.0

        return max(0.0, final_score)


    def _get_cf_candidates(self, user_id, landmark_id=None):
        """Get candidates from collaborative filtering model only."""
        candidates = set()
        cf_items = []
        
        try:
            cf_items, _ = self.cf_model.get_recommendations(user_id, current_item_id=landmark_id, n_items=int(self.top_n*1.2))
            if cf_items:
                candidates.update(cf_items)
                self.logger.info(f"CF candidates: {cf_items}")
        except Exception as e:
            self.logger.error(f"CF candidate error: {str(e)}")
            
        return list(candidates), len(cf_items) > 0

    def _get_cb_candidates(self, user_id, landmark_id=None):
        """Get candidates from content-based model only."""
        candidates = set()
        cb_items = []
        
        try:
            cb_recs = self.cb_model.get_combined_top_recommendations(item_id=landmark_id, user_id=user_id, top_n=int(self.top_n*1.2))
            if not cb_recs.empty:
                cb_items = cb_recs['Landmark_ID'].tolist()
                candidates.update(cb_items)
                self.logger.info(f"CB candidates: {cb_items}")
        except Exception as e:
            self.logger.error(f"CB candidate error: {str(e)}")
            
        return list(candidates), len(cb_items) > 0

    def _get_candidate_items(self, user_id, landmark_id=None):
        """Get candidates from both CF and CB models with proper fallback strategy."""
        cf_candidates, cf_success = self._get_cf_candidates(user_id, landmark_id)
        cb_candidates, cb_success = self._get_cb_candidates(user_id, landmark_id)
        
        # Combine unique candidates from both models
        candidates = set(cf_candidates + cb_candidates)
        
        # For logging purposes
        self.logger.debug(f"CF Candidates: {cf_candidates}")
        self.logger.debug(f"CB Candidates: {cb_candidates}")
        self.logger.info(f"Total unique candidates: {len(candidates)}")
        
        return list(candidates), cf_success, cb_success

    def _is_unconsumed(self, user_id, item_id):
        if self.train_mask is None:
            return True
        if user_id in self.train_mask.index and item_id in self.train_mask.columns:
            val = self.train_mask.loc[user_id, item_id]
            return pd.isna(val) or val == 0
        return True

    def recommend(self, user_id, landmark_id=None, n=None):
        n = n or self.top_n
        candidates, cf_success, cb_success = self._get_candidate_items(user_id, landmark_id)
        self.current_candidates = set(candidates)
        
        if candidates:
            scored = [
                (item, self.predict(user_id, item)) 
                for item in candidates 
                if self._is_unconsumed(user_id, item)
            ]
            scored = [(i, s) for i, s in scored if s > 0] 
            
            if scored:
                return sorted(scored, key=lambda x: x[1], reverse=True)[:n]
        
        try:
            cb_recs = self.cb_model.get_combined_top_recommendations(
                item_id=landmark_id, 
                user_id=user_id, 
                top_n=n
            )
            if not cb_recs.empty:
                self.logger.info("Falling back to CB-only recommendations")
                return [
                    (row['Landmark_ID'], row['similarity_score']) 
                    for _, row in cb_recs.head(n).iterrows()
                ]
        except Exception as e:
            self.logger.error(f"CB fallback failed: {str(e)}")
        
        self.logger.warning("Falling back to top popular items")
        return [(item[0], item[1]) for item in self.top_popular_items[:n]]

    def evaluate(self, matrix=None, mask=None, current_item=None, k_values=[5, 7, 10]):
        """
        Evaluate hybrid model using multiple recommendation metrics.

        Args:
            matrix: Test user-item matrix
            mask: Consumed mask for filtering
            current_item: Optional item to exclude
            k_values: List of k values for ranking metrics

        Returns:
            Dictionary of evaluation metrics
        """
        if matrix is None:
            matrix = self.test_matrix
        if mask is None:
            mask = self.test_mask
        current_item = current_item or None

        self.logger.info(f"Evaluating hybrid model with k-values {k_values}")

        results = {
            'rmse': 0.0,
            'precision': {k: [] for k in k_values},
            'recall': {k: [] for k in k_values},
            'hit_rate': {k: [] for k in k_values},
            'average_precision': [],
            'ndcg': {k: [] for k in k_values},
            'reciprocal_ranks': []
        }

        users = matrix.index.tolist()
        all_preds = []
        all_actuals = []

        for user_id in users:
            true_items = matrix.loc[user_id].dropna()
            if true_items.empty:
                continue

            for item_id, actual in true_items.items():
                if self._is_unconsumed(user_id, item_id):
                    pred = self.predict(user_id, item_id)
                    all_preds.append(pred)
                    all_actuals.append(actual)

            # Ranking-based metrics
            recs = [item for item, _ in self.recommend(user_id, current_item, n=max(k_values))]
            relevant_items = true_items.index.tolist()

            if not relevant_items or not recs:
                continue

            ap = 0.0
            hits = 0
            for i, item in enumerate(recs):
                if item in relevant_items:
                    hits += 1
                    ap += hits / (i + 1)
            ap /= len(relevant_items)
            results['average_precision'].append(ap)

            rr = 0.0
            for rank, item in enumerate(recs, start=1):
                if item in relevant_items:
                    rr = 1.0 / rank
                    break
            results['reciprocal_ranks'].append(rr)

            for k in k_values:
                recs_at_k = recs[:k]
                hits_at_k = len(set(recs_at_k) & set(relevant_items))
                precision_k = hits_at_k / k
                recall_k = hits_at_k / len(relevant_items)

                gains = [1 if item in relevant_items else 0 for item in recs_at_k]
                dcg = sum(g / np.log2(i + 2) for i, g in enumerate(gains))

                ideal_gains = [1] * min(len(relevant_items), k)
                idcg = sum(g / np.log2(i + 2) for i, g in enumerate(ideal_gains))

                ndcg_k = dcg / idcg if idcg > 0 else 0.0

                results['precision'][k].append(precision_k)
                results['recall'][k].append(recall_k)
                results['hit_rate'][k].append(1.0 if hits_at_k > 0 else 0.0)
                results['ndcg'][k].append(ndcg_k)

        # Aggregate metrics
        results['map'] = np.mean(results['average_precision']) if results['average_precision'] else 0.0
        results['mrr'] = np.mean(results['reciprocal_ranks']) if results['reciprocal_ranks'] else 0.0
        results['rmse'] = np.sqrt(mean_squared_error(all_actuals, all_preds)) if all_preds else 0.0
        results['mae'] = mean_absolute_error(all_actuals, all_preds) if all_preds else 0.0
        for k in k_values:
            for metric in ['precision', 'recall', 'hit_rate', 'ndcg']:
                values = results[metric][k]
                results[metric][k] = np.mean(values) if values else 0.0

        results['user_coverage'] = len(users) / len(matrix.index) if matrix is not None else 0
        return results

      
    def plot_training_progress(self,errors: List[float]):
      """Plot the training error over epochs."""
      plt.figure(figsize=(10, 5))
      plt.plot(range(1, len(errors) + 1), errors, 'b-', marker='o')
      plt.title('Training Progress')
      plt.xlabel('Epoch')
      plt.ylabel('RMSE')
      plt.grid(True)
      plt.tight_layout()
      plt.show()

    def plot_metric_comparison(self,results: Dict, k_values: List[int] = [5, 10, 20]):
        """Plot precision, recall and hit rate at different k values."""
        metrics = ['precision', 'recall', 'hit_rate']

        plt.figure(figsize=(12, 6))

        x = np.arange(len(k_values))
        width = 0.25

        for i, metric in enumerate(metrics):
            values = [results[metric][k] for k in k_values]
            plt.bar(x + (i-1)*width, values, width, label=metric.capitalize())

        plt.xlabel('k value')
        plt.ylabel('Score')
        plt.title('Recommendation Performance Metrics')
        plt.xticks(x, k_values)
        plt.legend()
        plt.grid(True, axis='y')
        plt.tight_layout()
        plt.show()

    def plot_precision_recall_ndcg_curves(self,results: Dict, k_values: List[int]):
        """Plot precision, recall and NDCG curves at different k values."""
        metrics = ['precision', 'recall', 'ndcg']
        plt.figure(figsize=(12, 6))

        for metric in metrics:
            values = [results[metric][k] for k in k_values]
            plt.plot(k_values, values, marker='o', label=metric.upper())

        plt.xlabel('k')
        plt.ylabel('Score')
        plt.title('Evaluation Metrics by k')
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plt.show()

    def plot_overall_metrics(self,map_val, mrr_val, coverage_val):
        """Plot overall metrics like MAP, MRR, and User Coverage."""
        metrics = ['MAP', 'MRR', 'User Coverage']
        values = [map_val, mrr_val, coverage_val]

        plt.figure(figsize=(8, 5))
        sns.barplot(x=metrics, y=values, palette='coolwarm')
        plt.title("Overall Evaluation Metrics")
        plt.ylim(0, 1.05)
        plt.grid(True, axis='y')
        plt.tight_layout()
        plt.show()

    def plot_scoring_distribution(self,matrix: pd.DataFrame, title: str = "Rating Distribution"):
        """Plot the distribution of ratings in the matrix."""
        # Get non-null ratings
        ratings = matrix.values[~np.isnan(matrix.values)]

        plt.figure(figsize=(10, 5))
        plt.hist(ratings, bins=20, color='blue', alpha=0.7)
        plt.title(title)
        plt.xlabel('Rating Value')
        plt.ylabel('Count')
        plt.grid(True)
        plt.tight_layout()
        plt.show()

    def plot_user_item_interactions(self,matrix, sample_size=50):
        """Plot a heatmap of user-item interactions for a sample of users and items."""
        # Sample users and items if the matrix is large
        if matrix.shape[0] > sample_size:
            users_sample = np.random.choice(matrix.index, sample_size, replace=False)
            sample_matrix = matrix.loc[users_sample]
        else:
            sample_matrix = matrix

        if sample_matrix.shape[1] > sample_size:
            items_sample = np.random.choice(sample_matrix.columns, sample_size, replace=False)
            sample_matrix = sample_matrix[items_sample]

        plt.figure(figsize=(12, 10))
        sns.heatmap(sample_matrix, cmap='viridis', cbar_kws={'label': 'Rating Value'})
        plt.title('User-Item Interaction Heatmap (Sample)')
        plt.xlabel('Items')
        plt.ylabel('Users')
        plt.show()

    def plot_latent_factors(self,user_factors, item_factors, n_components=2):
        """Plot users and items in the latent factor space using PCA."""
        # Reduce dimensions to 2 for visualization
        pca = PCA(n_components=n_components)

        # Transform user and item factors
        user_factors_2d = pca.fit_transform(user_factors)
        item_factors_2d = pca.transform(item_factors)

        plt.figure(figsize=(10, 8))

        # Plot users
        plt.scatter(user_factors_2d[:, 0], user_factors_2d[:, 1],
                    c='blue', marker='o', alpha=0.5, label='Users')

        # Plot items
        plt.scatter(item_factors_2d[:, 0], item_factors_2d[:, 1],
                    c='red', marker='x', alpha=0.5, label='Items')

        plt.title('Latent Factor Space Visualization (PCA)')
        plt.xlabel(f'Principal Component 1 (Variance: {pca.explained_variance_ratio_[0]:.2f})')
        plt.ylabel(f'Principal Component 2 (Variance: {pca.explained_variance_ratio_[1]:.2f})')
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plt.show()


######################################################################################################################################################################################
import pymysql

def load_items_from_mysql():
    connection = pymysql.connect(
        host="localhost",
        user="root",       # Replace with your MySQL username
        password="2468",   # Replace with your MySQL password
        database="tourism"
    )
    
    # Query the places table
    query = "SELECT * FROM places"
    
    # Load into a DataFrame
    items_df = pd.read_sql(query, connection)
    
    connection.close()
    return items_df

######################################################################################################################################################################################

def main():
    # Load prepared data
    with open("/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/models/prepared_data.pkl", "rb") as f:
        data = pickle.load(f)

    # Extract components
    cf_train_matrix, cf_train_mask = data["cf_matrices"]["train"]
    cf_test_matrix, cf_test_mask = data["cf_matrices"]["test"]
    cb_train_matrix, cb_train_mask = data["cb_matrices"]["train"]
    cb_test_matrix, cb_test_mask = data["cb_matrices"]["test"]
    meta_features = data["meta_features"]
    top_popular = data["top_popular"]

    # Load landmark content data for CB recommender
    items_df = pd.read_csv(r"/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/rec_data/Landmarks.csv") #load_items_from_mysql() 

    # --- Train Collaborative Filtering model ---
    cf_model = CollaborativeFilteringRecommender(
        n_factors=5, n_epochs=120, learning_rate=0.004, reg=0.05, test_matrix = cf_test_matrix, consumed_mask=cf_test_mask
    )
    print("Training CF model...")
    cf_model.fit(cf_train_matrix)

    # --- Train Content-Based model ---
    print("Training CB model...")
    cb_model = NMFContentRecommender_merged(num_topics=5)
    tfidf = cb_model.prepare_corpus(items_df)
    cb_model.train_nmf_model(tfidf)
    cb_model.add_weighted_item_topics_to_user_profile(cb_train_matrix)

    # --- Train Hybrid (FWLS) model ---
    print("Training Hybrid model...")
    hybrid_model = FWLSHybridRecommender(
        cf_model=cf_model,
        cb_model=cb_model,
        train_matrix=cb_train_matrix,
        test_matrix = cb_test_matrix,
        train_mask = cb_train_mask,
        test_mask = cb_test_mask,
        meta_features_df=meta_features,
        top_popular_items=top_popular,
        top_n=10
    )
    hybrid_model.fit()

    # --- Save all models ---
    print("Saving trained models...")
    with open(r"/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/models/cf_model.pkl", "wb") as f:
        pickle.dump(cf_model, f)

    with open(r"/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/models/cb_model.pkl", "wb") as f:
        pickle.dump(cb_model, f)

    with open(r"/content/drive/MyDrive/GP2024/Phase 2/recommendation_files/models/hybrid_model.pkl", "wb") as f:
        pickle.dump(hybrid_model, f)

    print("All models trained and saved.")

if __name__ == "__main__":
    main()
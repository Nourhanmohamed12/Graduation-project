import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import time
from datetime import datetime
import subprocess
import os
import json

# Constants
MIN_BATCH_SIZE = 5 # for testing; set to 5 in production
SLEEP_DURATION = 60  # for testing; set to 60 in production
MAX_EMPTY_DURATION_MINUTES = 120 #604800
MAX_EMPTY_CYCLES = MAX_EMPTY_DURATION_MINUTES // SLEEP_DURATION
RETRAIN_THRESHOLD = 3000  # for testing; set to 500 in production
INTERACTION_CSV_PATH = r"C:\Users\Dell G3\Downloads\project\rec_backend\rec_data\interactions_cleaned.csv"
STATE_FILE = r"C:\Users\Dell G3\Downloads\project\rec_backend\utils\collector_state.json"

# Firebase Init
cred = credentials.Certificate(r'C:\Users\Dell G3\Downloads\project\rec_backend\rec-firebase-adminsdk.json.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# ---- Persistent State Management ----
def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    else:
        return {"interaction_since_last_train": 0}

def save_state(state):
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f)


state = load_state()
interaction_since_last_train = state.get("interaction_since_last_train", 0)
empty_count = 0

# ---- Firebase Operations ----
def fetch_batch(batch_size=5):
    docs = db.collection('interaction_queue').order_by('added_at').limit(batch_size).stream()
    data = []
    refs_to_delete = []
    for doc in docs:
        data.append(doc.to_dict())
        refs_to_delete.append(doc.reference)
    return data, refs_to_delete

def delete_docs(refs):
    for ref in refs:
        ref.delete()

def save_to_firestore(data, target_collection='interaction_dataset'):
    batch = db.batch()
    for entry in data:
        new_ref = db.collection(target_collection).document()
        batch.set(new_ref, entry)
    batch.commit()

def export_to_csv(collection_name='interaction_dataset', export_path=INTERACTION_CSV_PATH):
    docs = db.collection(collection_name).stream()
    data = [doc.to_dict() for doc in docs]

    if not data:
        print("No data to export.")
        return 0

    # Remove unwanted fields (e.g., "added_at")
    for d in data:
        d.pop("added_at", None)

    df = pd.DataFrame(data)
    df.to_csv(export_path, index=False)
    print(f"Exported {len(df)} rows to {export_path}")
    return len(df)

# ---- Retraining ----
def retrain_models():
    print("Starting retraining pipeline...")
    try:
        # Export updated CSV
        export_to_csv()

        # # Run prepare_data.py
        # subprocess.run(["python", "python/rec_prepare_data.py"], check=True)

        # # Run train_models.py
        # subprocess.run(["python", "python/rec_models_train.py"], check=True)

        print("Retraining complete.")

    except subprocess.CalledProcessError as e:
        print(f"Retraining failed at step: {e}")
    except Exception as ex:
        print(f"Unexpected error during retraining: {ex}")

# ---- Main Loop ----
print("Evidence Collector started...")

while True:
    batch_data, refs = fetch_batch(MIN_BATCH_SIZE)

    if len(batch_data) >= MIN_BATCH_SIZE or empty_count >= MAX_EMPTY_CYCLES:
        print(f"[{datetime.now()}] Saving {len(batch_data)} interactions to Firestore")

        if batch_data:
            save_to_firestore(batch_data)
            delete_docs(refs)
            interaction_since_last_train += len(batch_data)
            state["interaction_since_last_train"] = interaction_since_last_train
            save_state(state)

        empty_count = 0
    else:
        print(f"[{datetime.now()}] Only {len(batch_data)} interactions. Waiting... ({empty_count + 1}/{MAX_EMPTY_CYCLES})")
        empty_count += 1

    # Trigger retraining if enough interactions have been collected
    if interaction_since_last_train >= RETRAIN_THRESHOLD:
        retrain_models()
        interaction_since_last_train = 0
        state["interaction_since_last_train"] = 0
        save_state(state)

    time.sleep(SLEEP_DURATION)

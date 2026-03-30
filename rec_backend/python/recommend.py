# # recommend.py
import pickle
import os
import sys
import json
import pymysql
from rec_models_train import FWLSHybridRecommender, CollaborativeFilteringRecommender, NMFContentRecommender_merged
import decimal

def load_model(path):
    with open(path, "rb") as f:
        return pickle.load(f)

def get_landmark_data(landmark_ids):
    # Connect to MySQL
    connection = pymysql.connect(
        host="localhost",
        user="root",
        password="2468",
        database="tourism",
        cursorclass=pymysql.cursors.DictCursor,
    )

    try:
        with connection.cursor() as cursor:
            format_ids = "', '".join(landmark_ids)
            query = f"SELECT * FROM places WHERE Landmark_ID IN ('{format_ids}')"
            cursor.execute(query)
            result = cursor.fetchall()

            # Reorder results to match landmark_ids order
            id_to_item = {str(item["Landmark_ID"]): item for item in result}
            ordered_result = [id_to_item[str(lid)] for lid in landmark_ids if str(lid) in id_to_item]
            return ordered_result
    finally:
        connection.close()
        
def recommend(user_id, current_item_id, top_n=10):
    hybrid_model = load_model(r"C:\Users\Dell G3\Downloads\project\rec_backend\models\hybrid_model.pkl")
    recs = hybrid_model.recommend(user_id, landmark_id=current_item_id, n=top_n)
    ids_only = [item[0] for item in recs]
    return get_landmark_data(ids_only)

def convert_decimal(obj):
    if isinstance(obj, decimal.Decimal):
        return float(obj)
    raise TypeError(f"Type {type(obj)} not serializable")

if __name__ == "__main__":
    try:
        input_data = sys.stdin.read()
        print("Received input:", input_data, file=sys.stderr)
        params = json.loads(input_data)
        user_id = params["user_id"] 
        current_item_id = params["landmark_id"].strip('"')

        print(f"Parsed user_id: {user_id}", file=sys.stderr)
        print(f"Parsed landmark_id: {current_item_id}", file=sys.stderr)

        #user_id = "29"
        #current_item_id = "ANC_04"
    # # Call recommend function and log
        recommendations = recommend(user_id, current_item_id, top_n=10)
        print(f"Generated recommendations: {recommendations}", file=sys.stderr)

            # ONLY this goes to stdout
        sys.stdout.write(json.dumps(recommendations, default=convert_decimal))

    except Exception as err:
        sys.stdout.write(json.dumps({"error": str(err)}))
        print("Full traceback:", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)

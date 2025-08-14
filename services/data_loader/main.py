from fastapi import FastAPI
from data_loader import DataLoader
from base_model import DataRow

app = FastAPI()
loader = DataLoader()

@app.get("/data", response_model=list[DataRow])
def get_data():
    "Load the data via the FastAPI Server"
    return loader.get_all()

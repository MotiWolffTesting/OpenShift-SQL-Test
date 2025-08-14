from pydantic import BaseModel

class DataRow(BaseModel):
    """Represents a row of data the relevant columns"""
    id: int
    first_name: str
    last_name: str
    
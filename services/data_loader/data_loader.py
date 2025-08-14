import os
import mysql.connector

class DataLoader:
    """Loads the data from the mysql server"""
    def __init__(self): 
        "Initalize variables for connection to mysql server"
        self.host = os.getenv("MYSQL_HOST")
        self.user = os.getenv("MYSQL_USER")
        self.password = os.getenv("MYSQL_PASSWORD")
        self.database = os.getenv("MYSQL_DATABASE")
        self.port = os.getenv("MYSQL_PORT", "3306")
        
    def get_all(self):
        "Connect to server and load data"
        connection = mysql.connector.connect(
            host=self.host, port=self.port, user=self.user,
            password=self.password, database=self.database,
        )
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("SELECT id, first_name, last_name FROM data;")
            rows = cursor.fetchall()
            return rows
            cursor.close()
        finally:
            connection.close()
            
    

    
           



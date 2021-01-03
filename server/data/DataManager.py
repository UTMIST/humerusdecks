import psycopg2
import json

class DataManager:

    # initialize DataManager class with file containing postgres DB access info
    def __init__(self, file):
        self.file = file

    # Returns a list of dictionaries containing each game's lobby data in JSON format
    def fetchGameData(self):

        f = open(file, "r")

        DB_NAME = (f.readline()).strip()
        DB_USER = (f.readline()).strip()
        DB_PASS = (f.readline()).strip()
        DB_HOST = (f.readline()).strip()
        DB_PORT = (f.readline()).strip()

        print(DB_NAME, DB_USER, DB_PASS, DB_HOST, DB_PORT)

        conn = psycopg2.connect(database = DB_NAME, user = DB_USER, password = DB_PASS, 
                                        host = DB_HOST, port = DB_PORT)

        print("Successfully connected to database.")

        cur = conn.cursor()

        cur.execute("SELECT ID, LOBBY FROM massivedecks.lobbies")

        allGameData = []
        rows = cur.fetchall()
        
        for data in rows:
            print(data[0]) 
            rawGameData = data[1]
            allGameData.append(rawGameData.copy())

        print("Data selected")
        conn.close()

        return allGameData

file = "postgres_access.txt"
manager = DataManager(file)
manager.fetchGameData()
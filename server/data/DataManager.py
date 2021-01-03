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
            rawGameData = data[1]

            # Skip all data where a game was not played
            if "game" in rawGameData:
                allGameData.append(rawGameData.copy())
                print("Saved game " + str(data[0]) + " to dictionary and appended dictionary to list.") 

        print("All game data selected from database and stored in list of dictionaries.")
        conn.close()

        return allGameData

    # Accepts list of dictionaries as input and returns list of tuples (play, result) as output
    def cleanGameData(self, data):
        #print(data[17].keys())
        #f = open("json.txt", 'w')
        #f.write(json.dumps(data[17]))

        for idx, item in enumerate(data):
            
            if "game" in item:
                #print(item["game"]["history"])
                print(idx)
                print(item.keys())

        results = []
        return results

file = "postgres_access.txt"
manager = DataManager(file)
gameData = manager.fetchGameData()
results = manager.cleanGameData(gameData)
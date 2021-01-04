import psycopg2
import json

# A class to fetch and clean all game data from the Postgres DB for training 
class DataManager:

    # initialize DataManager class with text file containing postgres DB access info
    def __init__(self, file):
        self.file = file

    # Returns a list of dictionaries containing each game's lobby data in JSON format
    def fetchGameData(self):

        # Access Postgres DB credentials
        f = open(file, "r")

        # Connect to Postgres DB
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

            # Skip all rows where a game was not played and the game history is not empty
            if "game" in rawGameData:
                if rawGameData["game"]["history"]:
                    allGameData.append(rawGameData.copy())
                    print("Saved game " + str(data[0]) + " to dictionary and appended dictionary to list.") 

        print("All game data selected from database and stored in list of dictionaries.")
        conn.close()

        return allGameData

    # Accepts list of dictionaries as input and returns list of tuples (call, play, result) as output
    def cleanGameData(self, data):

        results = []

        for idx, game in enumerate(data):
            
            call = ""
            play = ""
            result = ""

            print("\nGame " + str(idx) + ": ")

            for idy, gameRound in enumerate(game["game"]["history"]):
                print("Round " + str(idy) + ": ")
                #plays = gameRound["plays"]
                #print("Plays: " + json.dumps(plays))
                #print("Number of players: " + str(len(gameRound["plays"])))
                print("Players: ")
                for player in gameRound["plays"]:
                    print(player)
                    for play in gameRound["plays"][player]["play"]:

                        print(play["text"])
                
                winner = int(gameRound["winner"])
                print("Winner: " + str(winner))
            
        return results

# Since thie file is .gitignored, download it from Google Drive
file = "postgres_access.txt"

manager = DataManager(file)
gameData = manager.fetchGameData()
results = manager.cleanGameData(gameData)
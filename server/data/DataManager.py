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

        # Loop through every game
        for game in data:

            # Loop through every round in the game
            for gameRound in game["game"]["history"]:
                
                # Declare call card, to be added to tuple
                call = gameRound["call"]["parts"]

                winner = int(gameRound["winner"])

                # Loop through every player in the round
                for player in gameRound["plays"]:

                    # Declare play card and play result, to be added to tuple
                    plays = []
                    won = False

                    # Set result as won if player ID matches winner ID
                    if int(player) == winner:
                        won = True

                    # Loop through every play made by the player
                    for play in gameRound["plays"][player]["play"]:
                        played = play["text"]
                        plays.append(played)


                    result = (call, plays, won)
                    results.append(result)

        print("Successfully cleaned all game data and returned it in a list of tuples.")
        return results

# Since thie file is .gitignored, download it from Google Drive
file = "postgres_access.txt"

manager = DataManager(file)
gameData = manager.fetchGameData()
gameResults = manager.cleanGameData(gameData)
#print(gameResults)
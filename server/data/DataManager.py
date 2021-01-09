import json
import psycopg2

# A class to fetch and clean all game data from the Postgres DB for training 
class DataManager:

    # initialize DataManager class with text file containing postgres DB access info
    def __init__(self, file):
        self.file = file
        self.parsed_data = None
    # Returns a list of dictionaries containing each game's lobby data in JSON format

    def fetch(self):
        """
        fills self.parsed_data
        """
        self.parsed_data = self.cleanGameData(self.fetchGameData())

    def toJson(self, filename):
        if self.parsed_data is None:
            self.fetch()
        json.dump(self.parsed_data, open(filename, 'w'))

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
        
        print("Saving games... Skipping all rows where a game was not played.")

        for data in rows:
            rawGameData = data[1]

            # Skip all rows where a game was not played and the game history is not empty
            if "game" in rawGameData:
                if rawGameData["game"]["history"]:
                    allGameData.append(rawGameData.copy())
                    print("Saved game from row " + str(data[0]) + " to dictionary and appended dictionary to list.") 

        print("All game data selected from database and stored in list of dictionaries.")
        conn.close()

        return allGameData

    # Accepts list of dictionaries as input and returns parsed data as output
    def cleanGameData(self, data):
        flatten = lambda t: [item for sublist in t for item in sublist]

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

                    # combine call and plays
                    # result = (call, plays, won)

                    call = flatten(call)
                    while _find_first_instance_by_type(call, dict) != -1:
                        call[_find_first_instance_by_type(call, dict)] = plays.pop(0)

                    sentence = "".join(call)


                    results.append((sentence, won))

        print("Successfully cleaned all game data and returned it in a list of tuples.")
        return results


def _find_first_instance_by_type(list, t):
    """
    returns index of first instance of type t, -1 otherwise
    list: list,
    t: type to look for 
    """
    for ind, itm in enumerate(list):
        if type(itm) == t:
            return ind
    return -1

if __name__ == "__main__":
    file = "postgres_access.txt"
    manager = DataManager(file)
    manager.fetch()
    manager.toJson('asdf.json')
    print(manager.parsed_data)
    gameData = manager.fetchGameData()
    gameResults = manager.cleanGameData(gameData)




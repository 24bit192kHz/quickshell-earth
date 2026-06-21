import sqlite3
import threading

local_data = threading.local()

def get_conn():
    if not hasattr(local_data, "conn"):
        print("Opening new connection")
        local_data.conn = sqlite3.connect("tiles.db")
    return local_data.conn

get_conn()
get_conn()

from flask import Flask
import os
import socket
import math

app = Flask(__name__)

@app.route("/")
def hello():



    html = "<h3>Hello {name}!</h3>" \
           "<b>Hostname:</b> {hostname}<br/>"

    # Forcing CPU usage
    #for num in range(1,1000000):
        #math.cos(math.sqrt((num*5678)/8));

    return html.format(name=os.getenv("NAME", "world"), hostname=socket.gethostname())

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)

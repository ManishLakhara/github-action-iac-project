from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/version')
def version():
    return jsonify({"version": "1.0.1"})
# add route at root with message "Happy Dipawali!!"
@app.route('/')
def home():
    return "Happy Dipawali!!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

import src.main.app

app = src.main.app.create_app()

if __name__ == "__main__":
    # Run a debug server.
    app.run(debug=True, host="0.0.0.0")

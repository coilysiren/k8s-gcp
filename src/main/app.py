import flask
import src.main.api


def create_app():
    """Create and configure an instance of the Flask application."""
    app = flask.Flask(__name__)
    app.register_blueprint(src.main.api.blueprint)

    return app

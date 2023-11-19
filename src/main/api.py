import flask


blueprint = flask.Blueprint("api", __name__, url_prefix="/api")


@blueprint.route("/healthcheck")
def healthcheck():
    """used for debugging purposes"""
    return flask.jsonify(
        {
            "status": "ok",
        }
    )

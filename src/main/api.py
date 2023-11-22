import flask


blueprint = flask.Blueprint("api", __name__, url_prefix="/")


@blueprint.route("")
def healthcheck_root():
    """used for debugging purposes"""
    return flask.jsonify(
        {
            "status": "ok",
        }
    )


@blueprint.route("api/healthcheck")
def healthcheck():
    """used for debugging purposes"""
    return flask.jsonify(
        {
            "status": "ok",
        }
    )

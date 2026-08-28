"""HTTP backend for the Azure API Management demonstration."""

import json
import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="hello", methods=["GET"])
def hello(req: func.HttpRequest) -> func.HttpResponse:
    """Return a small payload so APIM behavior is easy to observe."""
    name = req.params.get("name", "world").strip() or "world"
    return func.HttpResponse(
        json.dumps({"message": f"Hello, {name}!", "backend": "Azure Functions"}),
        status_code=200,
        mimetype="application/json",
    )

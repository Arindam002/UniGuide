from flask import request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

import config


limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[config.RATE_LIMIT_DEFAULT],
    storage_uri=config.RATE_LIMIT_STORAGE_URI,
    headers_enabled=True,
)


@limiter.request_filter
def is_options_request():
    return request.method == "OPTIONS"
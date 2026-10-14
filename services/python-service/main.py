import json
import os
from fastapi import FastAPI

app = FastAPI(title="python-service")

def load_config():
    config = {
        "service": "python-service",
        "environment": os.getenv("APP_ENVIRONMENT", "local"),
        "message": os.getenv("APP_MESSAGE", "Default local Python message"),
        "timeoutSeconds": int(os.getenv("APP_TIMEOUT_SECONDS", "30")),
        "featureFlagActive": os.getenv("APP_FEATURE_FLAG_ACTIVE", "false").lower() == "true",
    }
    
    config_path = "/etc/config/config.json"
    if os.path.exists(config_path):
        try:
            with open(config_path, "r") as f:
                file_config = json.load(f)
                config.update({k: v for k, v in file_config.items() if v is not None})
        except Exception as e:
            print(f"Error loading {config_path}: {e}")
            
    return config

@app.get("/health")
def health():
    return {"status": "UP"}

@app.get("/api/v1/config")
def get_config():
    return load_config()

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8086"))
    uvicorn.run(app, host="0.0.0.0", port=port)

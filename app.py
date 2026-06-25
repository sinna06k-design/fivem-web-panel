import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import numpy as np
from sklearn.ensemble import IsolationForest
import requests

app = FastAPI()

# Configuration
DISCORD_BOT_URL = "http://localhost:3000/api/ai-alert"
FIVEM_SERVER_URL = "http://localhost:30120/api/botcommand" # Replace with actual FiveM server IP/Port
SECRET_TOKEN = "NyxSecretToken2026"

# ---------------------------------------------------------
# AI Model Setup (Anomaly Detection)
# We use Isolation Forest to detect abnormal mouse/camera movements (Snapping)
# In a real scenario, this model would be trained on thousands of hours of legitimate player data.
# ---------------------------------------------------------
# Features: [Pitch_Delta, Yaw_Delta, Time_Between_Shots, Hit_Distance]
# Dummy training data (Normal human gameplay)
X_train = np.array([
    [0.5, 1.2, 500, 20.0],
    [1.0, 2.5, 600, 15.0],
    [0.2, 0.8, 450, 25.0],
    [2.1, 3.0, 700, 10.0],
    [0.8, 1.5, 550, 30.0],
])

model = IsolationForest(contamination=0.05, random_state=42)
model.fit(X_train)

# Models
class TelemetryData(BaseModel):
    playerId: int
    playerName: str
    pitchDelta: float
    yawDelta: float
    timeSinceLastShot: float
    hitDistance: float
    isHeadshot: bool

class TelemetryBatch(BaseModel):
    secret: str
    data: TelemetryData

@app.post("/api/analyze")
async def analyze_telemetry(batch: TelemetryBatch):
    if batch.secret != SECRET_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    player_data = batch.data
    
    # Prepare data for prediction [pitchDelta, yawDelta, timeSinceLastShot, hitDistance]
    X_test = np.array([[
        player_data.pitchDelta, 
        player_data.yawDelta, 
        player_data.timeSinceLastShot, 
        player_data.hitDistance
    ]])
    
    # Predict (-1 is anomaly/hack, 1 is normal)
    prediction = model.predict(X_test)[0]
    
    # Calculate an "AI Confidence Score" based on decision function
    score = model.decision_function(X_test)[0]
    
    # Custom Rules for Silent Aimbot (Extreme Distance + Instant Shot)
    is_silent_aim = False
    if player_data.hitDistance > 250 and player_data.timeSinceLastShot < 50:
        is_silent_aim = True

    # Custom Rules for Aimbot Snapping (Huge Angle change in 0ms)
    is_snapping = False
    if (abs(player_data.pitchDelta) > 40 or abs(player_data.yawDelta) > 40) and player_data.timeSinceLastShot < 100:
        is_snapping = True

    if prediction == -1 or is_silent_aim or is_snapping:
        # Generate Report
        reason = ""
        if is_silent_aim:
            reason = "AI DETECTED: Silent Aimbot (Impossible Hit Distance/Timing)"
        elif is_snapping:
            reason = "AI DETECTED: Aimbot (Inhuman Mouse Snapping)"
        else:
            reason = f"AI DETECTED: Abnormal Behavior (Anomaly Score: {score:.2f})"
        
        confidence = 95.0 if is_silent_aim or is_snapping else 80.0

        # Send alert to Discord Bot
        alert_payload = {
            "secret": SECRET_TOKEN,
            "playerId": player_data.playerId,
            "playerName": player_data.playerName,
            "reason": reason,
            "confidence": confidence,
            "telemetry": {
                "pitchDelta": player_data.pitchDelta,
                "yawDelta": player_data.yawDelta,
                "distance": player_data.hitDistance
            }
        }
        
        try:
            requests.post(DISCORD_BOT_URL, json=alert_payload)
        except Exception as e:
            print(f"Failed to reach Discord bot: {e}")

        # Send Ban command to FiveM Server
        ban_payload = {
            "secret": SECRET_TOKEN,
            "action": "ban",
            "playerId": player_data.playerId,
            "reason": reason
        }
        try:
            requests.post(FIVEM_SERVER_URL, json=ban_payload)
        except Exception as e:
            print(f"Failed to reach FiveM Server: {e}")

        return {"status": "flagged", "reason": reason}

    return {"status": "clean"}

import os

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    print(f"Starting AI AntiCheat Backend on port {port}...")
    uvicorn.run(app, host="0.0.0.0", port=port)

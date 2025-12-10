import os
import sys
import time
import numpy as np
import imageio.v2 as imageio
import mss

# =========================
# CONFIG
# =========================

# Get output path from command-line argument
# If no argument is given, use a default path
if len(sys.argv) > 1:
    video_path = sys.argv[1]
else:
    # Fallback to a default path in temp folder
    video_path = os.path.join(os.environ.get("TEMP", ""), "recording.mp4")

# Extract the directory from the full path to create it if needed
output_dir = os.path.dirname(video_path)
os.makedirs(output_dir, exist_ok=True)

fps = 30
duration = 35 # Changed to 35 to match your PowerShell wait time
frames = fps * duration
interval = 1 / fps

# =========================
# RECORDING
# =========================
with mss.mss() as sct:
    monitor = sct.monitors[1] # primary monitor
    with imageio.get_writer(video_path, fps=fps) as writer:
        # Removed print statements for silent operation
        for i in range(frames):
            start_time = time.time()
            screenshot = sct.grab(monitor)
            # ✅ FULL COLOR FIX: BGRA → RGB
            frame = np.array(screenshot)
            frame = frame[:, :, [2, 1, 0]] # swap BGR → RGB
            writer.append_data(frame)
            elapsed = time.time() - start_time
            time.sleep(max(0, interval - elapsed))

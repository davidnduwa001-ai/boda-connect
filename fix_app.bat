@echo off
echo ======================================
echo  BODA CONNECT - QUICK FIX SCRIPT
echo ======================================
echo.

echo [1/5] Running projection backfill...
curl -X POST "https://us-central1-boda-connect-49eb9.cloudfunctions.net/runBackfillProjections" -H "Content-Type: application/json" -d "{}"
echo.
echo.

echo [2/5] Cleaning Flutter build...
flutter clean
echo.

echo [3/5] Getting dependencies...
flutter pub get
echo.

echo [4/5] Analyzing code...
flutter analyze
echo.

echo ======================================
echo  NEXT STEPS:
echo ======================================
echo 1. Run: flutter run
echo 2. Wait for app to start
echo 3. LOG OUT from the app
echo 4. LOG BACK IN
echo 5. Pull down to refresh dashboard
echo.
echo If still not working, see TROUBLESHOOTING.md
echo ======================================
pause

$env:LIGHTRAG_SYNC_URL = "http://127.0.0.1:9621/documents/text"
$env:LIGHTRAG_SYNC_TOKEN = ""
$env:LIGHTRAG_QUERY_URL = "http://127.0.0.1:9621/query"
$env:LIGHTRAG_QUERY_TOKEN = ""
$env:LIGHTRAG_SYNC_TIMEOUT_MS = "5000"
$env:LIGHTRAG_QUERY_TIMEOUT_MS = "8000"
$env:LIGHTRAG_SYNC_MAX_RETRY = "3"

Write-Host "Starting MoocHub server with LightRAG integration..."
Write-Host "LIGHTRAG_SYNC_URL=$env:LIGHTRAG_SYNC_URL"
Write-Host "LIGHTRAG_QUERY_URL=$env:LIGHTRAG_QUERY_URL"

go run main.go

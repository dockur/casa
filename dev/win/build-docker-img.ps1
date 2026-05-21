# Define variables
$imageName = "casa-img"
$dockerfilePath = "../.."
$originalPath = Get-Location

# Change to the Dockerfile directory
Push-Location $dockerfilePath

try {
    # Build the Docker image
    Write-Host "Building the Docker image..."
    docker build -t $imageName .
}
catch {
    Write-Host $_
    exit $LASTEXITCODE
}
finally {
    # Ensure to return to the original path
    Pop-Location
}

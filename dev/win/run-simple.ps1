# Define variables
$imageName = "casa-os"
$containerName = "casa-os-dev"
$dockerfilePath = "../.."
$originalPath = Get-Location

# Change to the Dockerfile directory
Push-Location $dockerfilePath

try {
    # Build the Docker image
    Write-Host "Building the Docker image..."
    docker build -t $imageName .

    if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed. Exiting."
    }

    # Check if a container with the same name is already running
    Write-Host "Checking for existing container..."
    $existingContainer = docker ps -aq --filter "name=$containerName"

    if ($existingContainer) {
        Write-Host "Stopping and removing existing container..."
        docker stop $containerName
        docker rm $containerName

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stop and remove existing container. Exiting."
        }
    }

    # Run the Docker container
    Write-Host "Running the Docker container..."
    # DATA_ROOT must be in linux style path so we need to convert C:\DATA to c/DATA
    # you need to create a network for it to work docker network create meta
    docker run -d `
    -p 8080:8080 `
    -e DATA_ROOT=/c/DATA `
    -v C:\DATA:/DATA `
    -v /var/run/docker.sock:/var/run/docker.sock `
    --name $containerName $imageName
    #C:\Users\<YourUsername>\AppData\Local\Docker\wsl\data
    if ($LASTEXITCODE -ne 0) {
        throw "Docker run failed. Exiting."
    }

    Write-Host "Docker container $containerName is up and running."
}
catch {
    Write-Host $_
    exit $LASTEXITCODE
}
finally {
    # Ensure to return to the original path
    Pop-Location
}

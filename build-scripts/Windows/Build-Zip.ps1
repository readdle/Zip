Param(
    [string]$DependenciesPath,
    [string]$InstallPath
)

$ProjectRoot = "$(Resolve-Path ""$PSScriptRoot\..\.."")"
$SourcesPath = "$ProjectRoot\Zip"

$SourceFiles = Get-ChildItem -Path "$SourcesPath\*.swift" -Recurse -File

$ModuleName = "Zip"
$IntermediatesPath = "$ProjectRoot\.build\$ModuleName\Intermediates"
$ProductsPath = "$ProjectRoot\.build\$ModuleName"
if (-Not $DependenciesPath) {
    $DependenciesPath = "$ProjectRoot\.build\$ModuleName\Dependencies"
    New-Directory "$DependenciesPath"
}
if (-Not $InstallPath) {
    $InstallPath = "$ProjectRoot\.build\install"
    New-Directory "$InstallPath"
}

$BinDir = "$InstallPath\bin"
$IncludeDir = "$InstallPath\include"
$LibDir = "$InstallPath\lib"

$SwiftIncludePaths = "$InstallPath\include"    
$HeaderSearchPaths = "$InstallPath\include" 
$LibrarySearchPaths = "$InstallPath\lib"

$ZlibDependencySourceUrl = "https://spark-prebuilt-binaries.s3.amazonaws.com/zlib.zip"
$ZlibDependencyDir = "zlib"
$ZlibDependencyPath = "$DependenciesPath\$ZlibDependencyDir\zlib-win32-1"
$MiniZipDependencyPath = "$DependenciesPath\minizip"

$S3Key = $env:SPARK_PREBUILT_KEY
if (-Not $S3Key) {
    throw "Spark prebuilt storage key(SPARK_PREBUILT_KEY) is required"
}

$Configuration = @{
    ModuleName = $ModuleName

    WorkPath = $ProjectRoot

    IntermediatesPath = $IntermediatesPath
    ProductsPath = $ProductsPath

    BuildType = "Release"
    EnableOptimization = $true

    SwiftIncludePaths = $SwiftIncludePaths
    HeaderSearchPaths = $HeaderSearchPaths
    LibrarySearchPaths = $LibrarySearchPaths

    SourceFiles = $SourceFiles
}

Push-Task -Name $ModuleName -ScriptBlock {    
    Push-Task -Name "Initialize" -ScriptBlock {
        Invoke-VsDevCmd -Version "2022"

        Initialize-Toolchain
        Initialize-SDK
    }

    Push-Task -Name "Setup Zip Dependencies" -ScriptBlock {
        Invoke-RestMethod -Uri $ZlibDependencySourceUrl -OutFile "$DependenciesPath\zlib.zip" -UserAgent $S3Key
        Expand-Archive -Path "$DependenciesPath\zlib.zip" -DestinationPath $ZlibDependencyPath -Force
    }

    Push-Task -Name "MiniZip" -ScriptBlock {
        New-Directory "$MiniZipDependencyPath"
        Copy-Item -Path "$ProjectRoot\Zip\minizip\*" -Destination "$MiniZipDependencyPath" -Recurse -ErrorAction SilentlyContinue -PassThru | Write-Host
        $PDBOutputDirectoryPath = "$LibDir\minizip"
        New-Directory "$PDBOutputDirectoryPath"
        
        Push-Task -Name "CMake" -ScriptBlock {
            $CMakeArgs =
                "-G Ninja",
                "-DCMAKE_C_COMPILER=cl",
                "-DCMAKE_BUILD_TYPE=MinSizeRel",
                "-DCMAKE_INSTALL_PREFIX=$InstallPath",
                "-DCMAKE_COMPILE_PDB_OUTPUT_DIRECTORY=$PDBOutputDirectoryPath",
                "-DBUILD_SHARED_LIBS=NO",
                "-Dzlib_DIR=$ZlibDependencyPath" -join " "
            Invoke-CMakeTasks -WorkingDir "$MiniZipDependencyPath" -CMakeArgs $CMakeArgs
        }
    }

    Invoke-BuildModuleTarget -Configuration $Script:Configuration

    Push-Task -Name "Install" -ScriptBlock {
        Install-File "$ProductsPath\$ModuleName.dll" -Destination $BinDir
        Install-File "$ProductsPath\$ModuleName.swiftdoc" -Destination $IncludeDir
        Install-File "$ProductsPath\$ModuleName.swiftmodule" -Destination $IncludeDir
        Install-File "$ProductsPath\$ModuleName.exp" -Destination $LibDir
        Install-File "$ProductsPath\$ModuleName.lib" -Destination $LibDir
   }
}

$RunPixelStreamer = "C:\Unreal\iac\unreal\App\WindowsNoEditor\PixelStreamer.exe"
$arg1 = "
-AudioMixer"
$arg2 = "-PixelStreamingIP=localhost"
$arg3 = "-PixelStreamingPort=8888"
$arg4 = "-RenderOffScreen"

& $RunPixelStreamer $arg1 $arg2 $arg3 $arg4

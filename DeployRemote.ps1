$Dest = "\\172.17.60.133\somefile.txt"
$Source   = "e:\xxx\f1.txt"

$Username = "test"
$Password = "test"

$WebClient = New-Object System.Net.WebClient
$WebClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
$WebClient.UploadFile($Dest, $Source)
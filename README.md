<h1>Simple AWS Lambda to read from S3 bucket 
and saving headers of file and line count</h1><br>
Triggered by creating new file in S3 bucket - input/ folder. <br>
Project includes Terraform infrastructure for AWS. <br>

<h2>Deploy</h2>
<h3>In project folder</h3>
<li><code>dotnet restore</code>
<li><code>dotnet build</code>
<li><code>dotnet lambda package</code>
<h3>In Terraform folder</h3>
<li><code>terraform init</code> - only first run
<li><code>terraform apply</code>



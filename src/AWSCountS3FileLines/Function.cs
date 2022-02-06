using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using Amazon.S3.Model;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace AWSCountS3FileLines
{

    public class Function
    {
        private readonly AmazonS3Client _s3Client;
        
        public Function()
        {
            _s3Client = new AmazonS3Client();
        }

        public async Task FunctionHandler(S3Event s3Event, ILambdaContext context)
        {
            var lineCount = 0;
            var response = new StringBuilder();
            var outputPrefix = "output/";
            var eventFileKey = s3Event.Records[0].S3.Object.Key;
            var eventBucketName = s3Event.Records[0].S3.Bucket.Name;


            var file = await _s3Client.GetObjectAsync(eventBucketName, eventFileKey);

            using var fileStream = new StreamReader(file.ResponseStream);

            string line;
            while((line = await fileStream.ReadLineAsync()) != null)
            {
                if (lineCount == 0)
                {
                    response.AppendLine($"Headers: {line}");
                }

                lineCount++;
            }

            response.AppendLine($"Lines count: {lineCount}");

            _ = await _s3Client.PutObjectAsync(new PutObjectRequest
            {
                BucketName = eventBucketName,
                Key = $"{outputPrefix}{Guid.NewGuid()}.txt",
                ContentType = "text/plain",
                ContentBody = response.ToString()
            });
        }
    }
}

using System.IO;
using System.Linq;
using System.Net;
using static Build.BuildSteps;

namespace Build
{
    class Program
    {
        static void Main(string[] args)
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

            Orchestrator
                .CreateForTarget(args)
                .Then(TestSignedArtifacts, skip: !args.Contains("--signTest")) // skips on integrationTests
                .Then(Clean)
                .Then(LogIntoAzure, skip: !args.Contains("--ci")) // skips on integrationTests
                .Then(UpdatePackageVersionsForIntegrationTests, skip: !args.Contains("--integrationTests")) // skips on integrationTests
                .Then(RestorePackages, skip: !args.Contains("--integrationTests"))
                .Then(ReplaceTelemetryInstrumentationKey, skip: !args.Contains("--ci")) // skips on integrationTests
                .Then(DotnetPublish)
                .Then(FilterPowershellRuntimes)
                .Then(FilterPythonRuntimes)
                .Then(AddDistLib)
                .Then(AddTemplatesNupkgs)
                .Then(AddTemplatesJson)
                .Then(AddGoZip, skip: args.Contains("--integrationTests")) // Not sure if we need this. Check with Ahmed
                .Then(TestPreSignedArtifacts, skip: !args.Contains("--ci"))  // skips on integrationTests
                .Then(CopyBinariesToSign, skip: !args.Contains("--ci"))  // skips on integrationTests
                .Then(Test, skip: args.Contains("--integrationTests"))  // skips on integrationTests
                .Then(Zip)
                .Then(WritenItegrationTestBuildManifest, skip: !args.Contains("--integrationTests"))
                //.Then(UploadToStorage, skip: !args.Contains("--ci"))  // Delete this and add a step on devops
                .Run();
        }
    } 
}


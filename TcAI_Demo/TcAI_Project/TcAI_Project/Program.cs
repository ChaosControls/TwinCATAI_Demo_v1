using System;
using System.IO;
using System.Runtime.InteropServices;
using EnvDTE;

namespace TcAI_Project
{
    class Program
    {
        // ProgID for TcXaeShell — the standalone TwinCAT XAE IDE (VS 2017 shell).
        // If you are using TwinCAT inside full Visual Studio, change to:
        //   "VisualStudio.DTE.16.0"  (VS 2019)
        //   "VisualStudio.DTE.17.0"  (VS 2022)
        private const string DteProgId = "TcXaeShell.DTE.15.0";

        static void Main(string[] args)
        {
            if (args.Length == 0 || string.IsNullOrWhiteSpace(args[0]))
            {
                Console.Error.WriteLine("Usage: TcAI_Project <AmsNetId>");
                Console.Error.WriteLine("  Example: TcAI_Project 1.2.3.4.5.6");
                Environment.Exit(1);
            }

            string amsNetId = args[0].Trim();
            Console.WriteLine($"Target AMS Net ID : {amsNetId}");

            string solutionPath = ResolveSolutionPath();
            Console.WriteLine($"Solution          : {solutionPath}");

            DTE? dte = null;
            try
            {
                dte = LaunchTcXaeShell();

                // Keep TcXaeShell alive after this process exits so the user
                // can inspect the result.
                dte.UserControl = true;
                dte.MainWindow.Visible = true;

                // ---------------------------------------------------------------
                // Step 1 – Open the TwinCAT project
                // ---------------------------------------------------------------
                Console.WriteLine("\nOpening TwinCAT project...");
                dte.Solution.Open(solutionPath);
                Console.WriteLine("Solution opened.");

                // ---------------------------------------------------------------
                // Step 2 – Assign the target AMS Net ID
                //
                // project.Object exposes ITcSysManager2, cast as dynamic to avoid
                // a compile-time COM reference to TCatSysManagerLib.
                // ITcSysManager2.SetTargetNetId() sets the "Choose Target System"
                // AMS Net ID that will receive the activated configuration.
                // ---------------------------------------------------------------
                Console.WriteLine($"\nSetting target AMS Net ID to {amsNetId}...");
                dynamic systemManager = dte.Solution.Projects.Item(1).Object;
                systemManager.SetTargetNetId(amsNetId);
                Console.WriteLine("Target AMS Net ID set.");

                // ---------------------------------------------------------------
                // Step 3 – Activate the TwinCAT configuration
                //
                // ITcSysManager.ActivateConfiguration() compiles and downloads
                // the project configuration to the target (equivalent to clicking
                // "Activate Configuration" in TcXaeShell).
                // ---------------------------------------------------------------
                Console.WriteLine("\nActivating TwinCAT configuration...");
                systemManager.ActivateConfiguration();
                Console.WriteLine("Configuration activated.");

                // ---------------------------------------------------------------
                // Step 4 – Restart TwinCAT on the target
                //
                // ITcSysManager.StartRestartTwinCAT() starts TwinCAT if stopped,
                // or restarts it if already running, to apply the new configuration.
                // ---------------------------------------------------------------
                Console.WriteLine("\nRestarting TwinCAT on target...");
                systemManager.StartRestartTwinCAT();
                Console.WriteLine("TwinCAT restarted.");

                Console.WriteLine("\n=== Deployment Complete ===");
                Console.WriteLine($"  AMS Net ID : {amsNetId}");
                Console.WriteLine($"  Solution   : {Path.GetFileName(solutionPath)}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                // On failure only: shut down TcXaeShell and release the COM object.
                if (dte != null)
                {
                    try { dte.Quit(); } catch { /* shell may already be gone */ }
                    Marshal.ReleaseComObject(dte);
                }
                Environment.Exit(1);
            }
            // On success: do NOT release the COM object or call Quit().
            // UserControl = true means TcXaeShell is independent of this process,
            // so just let the process exit — TcXaeShell stays open.
        }

        // ---------------------------------------------------------------------------
        // Locate the .sln file inside TwinCAT_ProjectTemp.
        // Expected layout relative to compiled binary (net48 Debug/Release):
        //   TcAI_Demo/
        //     TwinCAT_ProjectTemp/        <-- .sln lives here
        //     TcAI_Project/
        //       TcAI_Project/
        //         bin/<Config>/net48/     <-- binary runs here
        // ---------------------------------------------------------------------------
        private static string ResolveSolutionPath()
        {
            string binaryDir = AppDomain.CurrentDomain.BaseDirectory;
            string projectTempPath = Path.GetFullPath(
                Path.Combine(binaryDir, @"..\..\..\..\..\TwinCAT_ProjectTemp"));

            if (!Directory.Exists(projectTempPath))
            {
                Console.Error.WriteLine($"TwinCAT_ProjectTemp not found at: {projectTempPath}");
                Environment.Exit(1);
            }

            string[] solutions = Directory.GetFiles(
                projectTempPath, "*.sln", SearchOption.TopDirectoryOnly);

            if (solutions.Length == 0)
            {
                Console.Error.WriteLine(
                    $"No .sln file found in TwinCAT_ProjectTemp.\n" +
                    $"  Expected path: {projectTempPath}\n" +
                    $"  Place your TwinCAT 3 project solution there and re-run.");
                Environment.Exit(1);
            }

            if (solutions.Length > 1)
                Console.WriteLine($"Multiple .sln files found — using: {Path.GetFileName(solutions[0])}");

            return Path.GetFullPath(solutions[0]);
        }

        // ---------------------------------------------------------------------------
        // Instantiate a new TcXaeShell process via COM automation.
        // ---------------------------------------------------------------------------
        private static DTE LaunchTcXaeShell()
        {
            Type? dteType = Type.GetTypeFromProgID(DteProgId, throwOnError: false);
            if (dteType == null)
            {
                Console.Error.WriteLine(
                    $"ProgID '{DteProgId}' not found in registry.\n" +
                    $"  Verify TcXaeShell (TwinCAT 3 XAE) is installed, or update DteProgId " +
                    $"in Program.cs to match your installation.");
                Environment.Exit(1);
            }

            object? instance = Activator.CreateInstance(dteType);
            if (instance == null)
                throw new InvalidOperationException("Activator.CreateInstance returned null for DTE.");

            return (DTE)instance;
        }
    }
}

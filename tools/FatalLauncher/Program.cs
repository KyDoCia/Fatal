using System.Diagnostics;
using System.Windows.Forms;

static void Fail(string message)
{
    MessageBox.Show(message, "FATAL Launcher", MessageBoxButtons.OK, MessageBoxIcon.Error);
    Environment.Exit(1);
}

var executableDirectory = AppContext.BaseDirectory;
var repository = Directory.GetParent(executableDirectory)?.FullName;
if (repository is null || !File.Exists(Path.Combine(repository, "default.project.json")))
    Fail("Coloque FatalLauncher.exe dentro da pasta dist do repositório FATAL.");

var verification = Path.Combine(repository!, "tests", "verify.ps1");
var build = Path.Combine(repository!, "Fatal.rbxlx");
if (!File.Exists(verification)) Fail("tests/verify.ps1 não foi encontrado.");

var buildProcess = new ProcessStartInfo("powershell.exe")
{
    WorkingDirectory = repository,
    UseShellExecute = false,
    CreateNoWindow = true,
};
buildProcess.ArgumentList.Add("-NoProfile");
buildProcess.ArgumentList.Add("-ExecutionPolicy");
buildProcess.ArgumentList.Add("Bypass");
buildProcess.ArgumentList.Add("-File");
buildProcess.ArgumentList.Add(verification);

using (var process = Process.Start(buildProcess))
{
    if (process is null) Fail("Não foi possível iniciar a geração do place.");
    process!.WaitForExit();
    if (process.ExitCode != 0) Fail("A verificação falhou. Execute tests/verify.ps1 para ver os detalhes.");
}

if (!File.Exists(build)) Fail("Fatal.rbxlx não foi gerado.");

var versions = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Roblox", "Versions");
var studio = Directory.Exists(versions)
    ? Directory.EnumerateFiles(versions, "RobloxStudioBeta.exe", SearchOption.AllDirectories)
        .OrderByDescending(File.GetLastWriteTimeUtc)
        .FirstOrDefault()
    : null;
if (studio is null) Fail("Roblox Studio não foi encontrado neste computador.");

var studioProcess = new ProcessStartInfo(studio!) { UseShellExecute = true };
studioProcess.ArgumentList.Add(build);
Process.Start(studioProcess);

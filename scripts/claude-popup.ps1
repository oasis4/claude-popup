# Claude Code Popup: eigenes Benachrichtigungsfenster fuer Stop- und Notification-Hooks.
# Erscheint auch bei "Nicht stoeren", unten rechts auf dem Monitor mit dem Mauszeiger.
# Aufruf durch hooks/hooks.json: powershell.exe -File claude-popup.ps1 -Event Stop|Notification  (Hook-JSON auf stdin)
param([string]$Event = "Notification")

$ErrorActionPreference = 'SilentlyContinue'

# --- Hook-Daten von stdin lesen ---
[Console]::InputEncoding = [Text.Encoding]::UTF8
$data = $null
try { $data = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch {}

$cwd = if ($data.cwd) { $data.cwd } else { (Get-Location).Path }
$Project = Split-Path $cwd -Leaf
if (-not $Project) { $Project = $cwd }

if ($Event -eq 'Stop') {
  $Title  = "Claude ist fertig"
  $Detail = "Die Antwort ist bereit."
  if ($data.last_assistant_message) {
    $line = (($data.last_assistant_message -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
    $line = ($line -replace '[#*`>_]', '').Trim()
    if ($line.Length -gt 110) { $line = $line.Substring(0, 107) + "..." }
    if ($line) { $Detail = $line }
  }
} else {
  switch ($data.notification_type) {
    'permission_prompt' { $Title = "Claude braucht deine Freigabe" }
    'idle_prompt'       { $Title = "Claude wartet auf dich" }
    default             { $Title = "Claude braucht dich" }
  }
  $Detail = if ($data.message) { $data.message } else { "Schau kurz in die Session." }
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -Namespace CP -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern bool FreeConsole();
[DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
'@

# --- Fenster der Session finden: Terminal ueber die Konsole von claude.exe, sonst Claude Desktop ---
$global:cpTarget = [IntPtr]::Zero
$isTerminal = $false
$p =Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
while ($p -and $p.Name -ne 'claude.exe') { $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" }
if ($p) {
  [CP.Win]::FreeConsole() | Out-Null
  if ([CP.Win]::AttachConsole([uint32]$p.ProcessId)) {
    $global:cpTarget = [CP.Win]::GetAncestor([CP.Win]::GetConsoleWindow(), 3)
    $isTerminal = $global:cpTarget -ne [IntPtr]::Zero
    [CP.Win]::FreeConsole() | Out-Null
  }
}
if ($global:cpTarget -eq [IntPtr]::Zero) {
  $desk = Get-Process claude | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
  if ($desk) { $global:cpTarget = $desk.MainWindowHandle }
}

# Kein Popup, wenn das Terminal der Session ohnehin gerade im Vordergrund ist.
# Nicht fuer Claude Desktop: dort laufen mehrere Sessions im selben Fenster, das sichtbare Projekt ist nicht erkennbar.
if ($isTerminal -and[CP.Win]::GetForegroundWindow() -eq $global:cpTarget) { exit 0 }

# Nur ein Popup gleichzeitig: ein vorheriges schliessen
$pidFile = Join-Path $env:TEMP 'claude-popup.pid'
if (Test-Path $pidFile) {
  $old = Get-Content $pidFile | Select-Object -First 1
  if ($old -and $old -ne "$PID") { Get-Process -Id $old | Where-Object { $_.ProcessName -eq 'powershell' } | Stop-Process -Force }
}
Set-Content $pidFile $PID

[xml]$xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Margin="18" CornerRadius="8" Background="#2B2B2B" BorderBrush="#3D3D3D" BorderThickness="1">
  <Border.Effect><DropShadowEffect BlurRadius="30" ShadowDepth="6" Direction="270" Opacity="0.5" Color="Black"/></Border.Effect>
  <Border.Resources>
    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="Foreground" Value="#C8C8C8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bg" Background="Transparent" CornerRadius="4"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#3A3A3A"/><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bg" Property="Background" Value="#333333"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bg" Background="#383838" BorderBrush="#474747" BorderThickness="1" CornerRadius="4"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Background" Value="#424242"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bg" Property="Background" Value="#323232"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
  </Border.Resources>
  <Grid Margin="16,12,10,16">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Grid Grid.Row="0">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,40,0">
        <Ellipse Width="7" Height="7" Fill="#D97757" VerticalAlignment="Center" Margin="0,1,8,0"/>
        <TextBlock Text="Claude Code" Foreground="#A8A8A8" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12"/>
        <TextBlock x:Name="ProjectText" Foreground="#787878" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="12" TextTrimming="CharacterEllipsis"/>
      </StackPanel>
      <Button x:Name="Done" Style="{StaticResource Ghost}" Width="30" Height="28" HorizontalAlignment="Right" ToolTip="Erledigt">
        <TextBlock Text="&#xE73E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13"/>
      </Button>
    </Grid>
    <StackPanel Grid.Row="1" Margin="0,6,6,0">
      <TextBlock x:Name="TitleText" Foreground="#FFFFFF" FontFamily="Segoe UI Variable Display, Segoe UI" FontWeight="SemiBold" FontSize="15"/>
      <TextBlock x:Name="DetailText" Foreground="#BEBEBE" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" TextWrapping="Wrap" MaxHeight="54" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"/>
    </StackPanel>
    <Button x:Name="Open" Grid.Row="2" Style="{StaticResource Primary}" Height="32" Margin="0,14,6,0">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="&#xE8A7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Margin="0,1,8,0"/>
        <TextBlock x:Name="OpenText" Text="Zur Session" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" VerticalAlignment="Center"/>
      </StackPanel>
    </Button>
  </Grid>
</Border>
'@

$content = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$content.FindName('ProjectText').Text = "  $([char]0xB7)  $Project"
$content.FindName('TitleText').Text   = $Title
$content.FindName('DetailText').Text  = $Detail
# Claude Desktop laesst sich nur als Fenster nach vorne holen, nicht auf einen bestimmten Chat umschalten
if (-not $isTerminal) { $content.FindName('OpenText').Text = "Claude $([char]0xF6)ffnen" }

# Position vor dem Anzeigen berechnen (wichtig bei mehreren Monitoren mit Skalierung)
$W = 400
$content.Measure((New-Object System.Windows.Size($W, [double]::PositiveInfinity)))
$H = [math]::Ceiling($content.DesiredSize.Height)
$scr   = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
$scale = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width / [System.Windows.SystemParameters]::PrimaryScreenWidth
$wa = $scr.WorkingArea
$global:cpLeft = ($wa.Right / $scale) - $W

$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'; $win.AllowsTransparency = $true; $win.Background = 'Transparent'
$win.Topmost = $true; $win.ShowInTaskbar = $false; $win.ShowActivated = $false
$win.WindowStartupLocation = 'Manual'
$win.Width = $W; $win.Height = $H
$win.Top = ($wa.Bottom / $scale) - $H; $win.Left = $global:cpLeft + 40
$win.Opacity = 0
$win.Content = $content
$global:cpWin = $win

function global:Hide-CP {
  $global:cpHold.Stop()
  $global:cpWin.BeginAnimation([System.Windows.Window]::OpacityProperty, (New-Object System.Windows.Media.Animation.DoubleAnimation($global:cpWin.Opacity, 0, [TimeSpan]::FromMilliseconds(180))))
  $global:cpCloseT = New-Object System.Windows.Threading.DispatcherTimer
  $global:cpCloseT.Interval = [TimeSpan]::FromMilliseconds(200)
  $global:cpCloseT.Add_Tick({ $global:cpCloseT.Stop(); $global:cpWin.Close() })
  $global:cpCloseT.Start()
}

$content.FindName('Done').Add_Click({ Hide-CP })
$content.FindName('Open').Add_Click({
  $h = $global:cpTarget
  if ($h -ne [IntPtr]::Zero) {
    if ([CP.Win]::IsIconic($h)) { [CP.Win]::ShowWindow($h, 9) | Out-Null }
    [CP.Win]::SetForegroundWindow($h) | Out-Null
  }
  Hide-CP
})
$win.Add_MouseEnter({ $global:cpHold.Stop() })
$win.Add_MouseLeave({ $global:cpHold.Start() })

# Nach 8 s ausblenden (pausiert, solange die Maus darauf ist); spaetestens nach 5 min hart schliessen
$global:cpHold = New-Object System.Windows.Threading.DispatcherTimer
$global:cpHold.Interval = [TimeSpan]::FromSeconds(8)
$global:cpHold.Add_Tick({ Hide-CP })
$global:cpKill = New-Object System.Windows.Threading.DispatcherTimer
$global:cpKill.Interval = [TimeSpan]::FromMinutes(5)
$global:cpKill.Add_Tick({ $global:cpKill.Stop(); $global:cpWin.Close() })

$win.Add_Loaded({
  $ease = New-Object System.Windows.Media.Animation.CubicEase; $ease.EasingMode = 'EaseOut'
  $slide = New-Object System.Windows.Media.Animation.DoubleAnimation(($global:cpLeft + 40), $global:cpLeft, [TimeSpan]::FromMilliseconds(320))
  $slide.EasingFunction = $ease
  $global:cpWin.BeginAnimation([System.Windows.Window]::LeftProperty, $slide)
  $global:cpWin.BeginAnimation([System.Windows.Window]::OpacityProperty, (New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(220))))
  $global:cpHold.Start(); $global:cpKill.Start()
})
$win.ShowDialog() | Out-Null
if ((Get-Content $pidFile | Select-Object -First 1) -eq "$PID") { Remove-Item $pidFile }

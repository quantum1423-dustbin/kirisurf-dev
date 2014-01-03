using System;
using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace controller
{
	class MainClass
	{
		[DllImport("wininet.dll")]
		public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
		public static int INTERNET_OPTION_SETTINGS_CHANGED = 39;
		public static int INTERNET_OPTION_REFRESH = 37;
		static bool settingsReturn, refreshReturn;
		public static void Main (string[] args)
		{

			if (args [0] == "set") {
				Console.WriteLine ("Setting the proxy");
				int proxport = Convert.ToInt32 (args [1]);
				using (var RegKey = 
					       Registry.CurrentUser.OpenSubKey ("Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", true)) {
					RegKey.SetValue ("ProxyServer", "localhost:" + proxport.ToString ());
					RegKey.SetValue ("ProxyEnable", 1);
				}

				// These lines implement the Interface in the beginning of program 
				// They cause the OS to refresh the settings, causing IP to realy update
				settingsReturn = InternetSetOption (IntPtr.Zero, INTERNET_OPTION_SETTINGS_CHANGED, IntPtr.Zero, 0);
				refreshReturn = InternetSetOption (IntPtr.Zero, INTERNET_OPTION_REFRESH, IntPtr.Zero, 0);
			} else if (args [0] == "unset") {
				Console.WriteLine ("Unsetting the proxy");
				using (var RegKey = 
					Registry.CurrentUser.OpenSubKey ("Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", true)) {
					RegKey.SetValue ("ProxyEnable", 0);
				}

				// These lines implement the Interface in the beginning of program 
				// They cause the OS to refresh the settings, causing IP to realy update
				settingsReturn = InternetSetOption (IntPtr.Zero, INTERNET_OPTION_SETTINGS_CHANGED, IntPtr.Zero, 0);
				refreshReturn = InternetSetOption (IntPtr.Zero, INTERNET_OPTION_REFRESH, IntPtr.Zero, 0);
			}
		}
	}
}

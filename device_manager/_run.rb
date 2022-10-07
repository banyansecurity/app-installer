# create Zero Touch installers for specific device managers

def jamf(infile, outfile)
	txt = File.read(infile)

	# first 3 input parameters are reserved for Jamf internal use
	# https://docs.jamf.com/10.26.0/jamf-pro/administrator-guide/Scripts.html
	txt.gsub!(/(INVITE_CODE=).*$/, "\\1" + '"$4"')
	txt.gsub!(/(DEPLOYMENT_KEY=).*$/, "\\1" + '"$5"')
	txt.gsub!(/(APP_VERSION=).*$/, "\\1" + '"$6"')

	# single-user device with configuration profile set 
	txt.gsub!(/(DEVICE_OWNERSHIP=).*$/, "\\1" + '"C"')
	txt.gsub!(/(VENDOR_NAME=).*$/, "\\1" + '"Jamf"')
	txt.gsub!(/(MULTI_USER=).*$/, "\\1" + 'false')
	txt.gsub!(/(USERINFO_PATH=).*$/, "\\1" + '"/Library/Managed Preferences/userinfo.plist"')
	txt.gsub!(/(USERINFO_USER_VAR=).*$/, "\\1" + '"deploy_user"')
	txt.gsub!(/(USERINFO_EMAIL_VAR=).*$/, "\\1" + '"deploy_email"')

	File.write(outfile, txt)
end

def kandji(infile, outfile)
	txt = File.read(infile)

	# Kandji's Custom Scripts capability doesn't currently permit you to pass in input parameters
	# https://support.kandji.io/support/solutions/articles/72000558749-custom-scripts-overview
	txt.gsub!(/(INVITE_CODE=).*$/, "\\1" + '"<YOUR_INVITE_CODE>"')
	txt.gsub!(/(DEPLOYMENT_KEY=).*$/, "\\1" + '"<YOUR_DEPLOYMENT_KEY>"')
	txt.gsub!(/(APP_VERSION=).*$/, "\\1" + '"<YOUR_APP_VERSION (optional)>"')	

	# single-user device; user details in Global Variables
	# https://support.kandji.io/support/solutions/articles/72000560519
	txt.gsub!(/(DEVICE_OWNERSHIP=).*$/, "\\1" + '"C"')
	txt.gsub!(/(VENDOR_NAME=).*$/, "\\1" + '"Kandji"')
	txt.gsub!(/(MULTI_USER=).*$/, "\\1" + 'false')
	txt.gsub!(/(USERINFO_PATH=).*$/, "\\1" + '"/Library/Managed Preferences/io.kandji.globalvariables.plist"')
	txt.gsub!(/(USERINFO_USER_VAR=).*$/, "\\1" + '"FULL_NAME"')
	txt.gsub!(/(USERINFO_EMAIL_VAR=).*$/, "\\1" + '"EMAIL"')

	File.write(outfile, txt)
end

def intune_windows(infile, outfile)
	txt = File.read(infile)

	# Intune's PowerShell script capability doesn't currently permit you to pass in input parameters
	# https://docs.microsoft.com/en-us/mem/intune/apps/intune-management-extension
	txt.gsub!(/(\$INVITE_CODE = ).*$/, "\\1" + '"<YOUR_INVITE_CODE>"')
	txt.gsub!(/(\$DEPLOYMENT_KEY = ).*$/, "\\1" + '"<YOUR_DEPLOYMENT_KEY>"')
	txt.gsub!(/(\$APP_VERSION = ).*$/, "\\1" + '"<YOUR_APP_VERSION (optional)>"')	

	# single-user device; user details available because joined to Azure AD domain
	# https://nerdymishka.com/articles/azure-ad-domain-join-registry-keys/
	txt.gsub!(/(\$DEVICE_OWNERSHIP = ).*$/, "\\1" + '"C"')
	txt.gsub!(/(\$VENDOR_NAME = ).*$/, "\\1" + '"Intune"')
	txt.gsub!(/(\$MULTI_USER = ).*$/, "\\1" + 'false')

	File.write(outfile, txt)
end


jamf("../banyan-macos.sh", "banyan-macos-jamf.sh")
kandji("../banyan-macos.sh", "banyan-macos-kandji.sh")
intune_windows("../banyan-windows.ps1", "banyan-windows-intune.ps1")

# TODO
#intune_macos("../banyan-macos.sh", "banyan-macos-intune.sh")
#ws1_windows("../banyan-windows.ps1", "banyan-windows-ws1.ps1")
#ws1_macos("../banyan-windows.ps1", "banyan-macos-ws1.sh")

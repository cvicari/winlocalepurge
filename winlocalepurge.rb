require 'logger'
require 'getoptlong'
require 'fileutils'
require 'yaml'

# TODO UAC in windows 8
# TODO each program could have a pattern to look for. For example, qBitTorrent is qt_<shortlang>.qm

Possible_program_folders = ["Program Files", "Program Files (x86)", "PortableApps"]

Known_programs = [
	"BleachBit",
	"Dia",
	"GIMP", "GIMP 2", # share/locale
	"gPodder",
	"7-Zip",
	"Notepad++",
	"CrystalDiskInfo", "CrystalDiskMark", "PeaZip",
	"PortableApps.com",
	"SmartDefrag", # App/Language
	"SystemExplorer",
	"Spybot", # locale
	"WiseDiskCleaner", "Wise/Wise Disk Cleaner", # Languages
	"WiseRegistryCleaner", "Wise/Wise Registry Cleaner", # Languages
	"FileZilla FTP Client", "FileZilla", # locale
	"Skype", # ...
	"qBittorrent",
	"VideoLAN/VLC", "VLC",
	"BOINC",
	"SyMenu",
	"PortableApps.com",
	"XBMC",
	"IrfanView",
	"AbiWord",
	"FoxitReader",
	"Gnumeric",
	"Pidgin",
	"Opera",
	"draw.io", # locales
	"Bazaar", # locale
	"EaseUS/EaseUS Partition Master 10.0", # locale (folders)
	"TOSHIBA/System Setting", # Lang
	"XBMC", # language
	"Ditto", # Language
	"qemu", # share/locale
	"ReviverSoft/Start Menu Reviver/Languages", # Languages
	"MS VS Code", 	# TODO visual studio code C:\Users\claudio.vicari\Programmi\MS VS Code\locales
	"Microsoft Azure Storage Explorer"
	# TODO google chrome C:\Program Files (x86)\Google\Chrome\Application\40.0.2214.115\Locales
	# TODO ownCloud files all in the main folder
	# TODO azure storage explorer where in C:\Users\claudio.vicari\AppData\Local\Programs\Microsoft Azure Storage Explorer\locales
	# TODO postman C:\Users\claudio.vicari\AppData\Local\Postman\app-8.3.0\locales\
].sort

Locale_folders = [
	"locale", # VLC, BOINC, SyMenu, PortableApps.com, OperaPortable
	"share/locale", # gnumeric, pidgin, gtk in general, Easeus partition master
	"lang", #  7zip, foxit, but foxit has a folder named "Foxit Reader" with a space, in portableapps
	"localization", # notepad++
	"CdiResource/language", # CrystalDiskInfo
	"CdmResource/language", # CrystalDiskMark
	"res/lang", # PeaZip
	"language", # SmartDefrag, XBMC, SystemExplorer
	"languages", # WiseDiskCleaner, irfanview, pdfcreator, WiseRegistryCleaner
	"locales", # Filezilla, draw.io
	"translations", # qBittorrent
	"strings", # AbiWord
].sort

# TODO sort out everything? I could list all program folders, then for each program maintain a database of where there are locales, and clean
# TODO some program keeps locales in folders where there are other files... these programs need an expression declaring which files are locale files

class LocaleCleaner
	def initialize(driveRoot, logLevel)
		@driveRoot = driveRoot
		@log = Logger.new(STDOUT)
		if (logLevel != Logger::DEBUG)
			@log.formatter = proc do |severity, datetime, progname, msg|
				"#{msg}\n"
			end
		end
		@log.level = logLevel
		@programFolder = nil
	end

	def cleanAll(dryRun=true)
		@log.info "languages that will be kept: #{Languages_to_keep}"
		scanForProgramFolders
		toClean = scanForLocaleDirectories
		cleanedFilesSize = 0
		@log.info "dryRun selected, I won't remove anything" if dryRun
		toClean.each do |pathToClean|
			if File.file? pathToClean
				@log.info "cleaning file #{pathToClean}"
				cleanedFilesSize += File.size? pathToClean
			else
				@log.info "cleaning directory #{pathToClean}"
				cleanedFilesSize += dir_size(pathToClean)
			end
			if !dryRun
				FileUtils.remove_entry_secure pathToClean
			end
		end
		@log.info "Estimated cleaned files size #{formatBytesHumanReadable(cleanedFilesSize)}"
	end

	private

	def dir_size(dir_path)
		require 'find'
		size = 0
		Find.find(dir_path) { |f| size += File.size(f) if File.file?(f) }
		size
	end

	def formatBytesHumanReadable(bytes)
		kbytes = bytes/1024
		mbytes = kbytes/1024
		gbytes = mbytes/1024

		qty = gbytes
		descr = "Gb"
		if (gbytes < 1.5)
			qty = mbytes
			descr = "Mb"
		end
		if (mbytes < 1.5)
			qty = kbytes
			descr = "Kb"
		end
		if (kbytes < 1.5)
			qty = bytes;
			descr = "bytes";
		end
		return "#{qty} #{descr}"
	end

	def scanForLocaleDirectories
		toClean = []
		@log.info "Scanning for locale folders"
		known_programs = Array.new
		Known_programs.each do |programName|
			known_programs.push programName
			known_programs.push programName+"Portable"+"/App/"+programName
		end

		@programFolders.each do |programFolder|
			known_programs.each do |programName|
				progrPath = @driveRoot + "/" +programFolder + "/" + programName
				@log.debug "trying with folder #{progrPath}"
				File::directory? progrPath or next
				@log.debug "found folder #{progrPath}"
				Locale_folders.each do |localeFolderLowerCase|
					allCases = Array.new
					allCases.push localeFolderLowerCase
					allCases.push localeFolderLowerCase.capitalize
					allCases.push localeFolderLowerCase.upcase
					allCases.each do |localeFolder|
						localeFolderPath = progrPath + "/" + localeFolder
						File::directory? localeFolderPath or next
						@log.debug "\tscanning folder #{localeFolderPath}"
						languages = Dir.entries localeFolderPath
						languages.each do |lang|
							langFullPath = localeFolderPath + "/" + lang
							keep = false
							(lang == "." || lang == "..") and next
							Languages_to_keep.each do |lang_to_keep|
								# matches = lang[/^#{lang_to_keep}/i] # TODO: could look at the beginning of the string, but qBittorrent
									# keeps the language in the middle of the filename
								matches = lang[/#{lang_to_keep}/i] # match case-insensitive
								if matches != nil then
									@log.debug "#{lang} can not be deleted"
									keep = true
									break
								end
							end
							if !keep
								toClean << langFullPath
								@log.debug "#{lang} can be deleted"
							end
						end
						@log.debug "matched #{localeFolder}, skipping other cases of the same directory"
						break # we found a case that matches, so we can exit from the loop
					end # allCases.each
				end
			end
		end
		toClean
	end

	def scanForProgramFolders
		@log.info "Getting program folders, starting from #{@driveRoot}"
		@programFolders = Array.new
		entries = Dir.entries(@driveRoot)
		possible_program_folders = Possible_program_folders
		if ENV['ProgramFiles'] and ENV['ProgramFiles'].downcase.start_with? @driveRoot.chop.downcase
			program_files = ENV['ProgramFiles'].downcase
			program_files.slice! @driveRoot.downcase
			if program_files.start_with? "\\"
				program_files.slice! "\\"
			end
			possible_program_folders.push program_files
			@log.info "directory #{program_files} added from environment variables"
		end
		entries.each do |dir|
			next if dir.start_with? '.' # skip '.' and '..'
			next if File::file? @driveRoot+dir # skip files, only examine directories
			@log.debug "Scanning program folder named #{dir}"
			Possible_program_folders.each do |possibleFolder|
				dir_abs_path = File::absolute_path(@driveRoot+dir).downcase
				possible_folder_abs_path = File::absolute_path(possibleFolder).downcase
				if (dir.downcase == possibleFolder.downcase) or (dir_abs_path == possible_folder_abs_path)
					@programFolders.push dir
					@log.debug "Found program folder named #{dir}"
					break
				end
			end
		end
	end
end

# default values for command line switches
dryRun = true
logLevel = Logger::INFO

HELP_MSG = <<-EOF
usage: #{__FILE__} [OPTION] ... DIR

-h, --help:
   show help

--really-delete, -d:
	really delete files and folders (default: don't delete, only show what would happen)

--verbose [level]:
	the level of log verbosity, 0=WARN, 1=INFO, 2=DEBUG (default: 1)
EOF

# usare GetoptLong oppure 
opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--really-delete', '-d', GetoptLong::NO_ARGUMENT ],
	[ '--verbose', '-v', GetoptLong::REQUIRED_ARGUMENT ]
)
opts.each do |opt,arg|
	case opt
		when '--help'
			puts HELP_MSG
	  exit
		when '--really-delete'
			dryRun = false
		when '--verbose'
			logLevelAsNum = arg.to_i
			case logLevelAsNum
				when 0
					logLevel = Logger::ERROR
				when 1
					logLevel = Logger::INFO
				when 2
					logLevel = Logger::DEBUG
				else 
					puts 'verbosity level should be 0, 1 or 2'
					exit 1
			end
	end # case
end # opts.each

yamlProps = YAML.load_file("winlocalepurge.yaml")
Languages_to_keep = yamlProps["Languages_to_keep"] or abort "Error: please specify Languages_to_keep in winlocalepurge.yaml file"

rootFolder = ARGV.shift

if rootFolder == nil
	abort HELP_MSG
end

if rootFolder.include? "//" or rootFolder.include? "\\\\" or rootFolder.include? "\\/" or rootFolder.include? "/\\"
	abort "please specify a valid root folder, that does not contain double slashes"
end

if rootFolder.length > 1 && (rootFolder.end_with? "\\" or rootFolder.end_with? "/")
	rootFolder = rootFolder.chop
end

if match = rootFolder.match(/^([a-zA-Z]):?$/i)
	rootFolder = "#{match.captures[0]}:/" 
end

if !(File.directory? rootFolder)
	abort "specified path \"#{rootFolder}\" is not a directory, please specify a valid directory"
end

rootFolder = File::absolute_path rootFolder

localeCleaner = LocaleCleaner.new(rootFolder, logLevel)
localeCleaner.cleanAll(dryRun)

# experiments: on my IBM_2GB pendrive, 819Mb occupied, 42,3MB free => 73Mb freed, thus 119Mb free

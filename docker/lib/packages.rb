require 'rake'
require 'rake/tasklib'
require 'xmlrpc/client'
require 'rubygems'
require_relative 'utils'

class Packages < ::Rake::TaskLib
	# only attempt to build .rpm's on these platforms (as reported by ohai[:platform])
	RPM_PLATFORMS = %w[centos redhat]

	def initialize(name, params)
		@name = name
		@params = params
		@fpmparams = params[:fpm]
		@arch = ohai[:kernel][:machine]
		@pkgname = "#{@name}-#{@fpmparams[:version]}-#{@fpmparams[:iteration]}.#{@arch}.rpm"

		allTasks unless @name.nil?
	end

	def allTasks
		default
		qSatellite
		buildRpm
		uploadRpmSatellite
		clobber
	end

	def default
		task :default => [ :clobber, :querySatellite, :buildRpm, :uploadToSatellite ]
	end


	def clobber
		desc "Remove any generated file"
		task :clobber do
			logger.info 'Executing task clobber'
			logger.info "rm -rf #{@fpmparams[:rpm_output_dir]}#{@pkgname}"
			rm_rf("#{@fpmparams[:rpm_output_dir]}#{@pkgname}", :verbose => false)
			logger.info 'Task clobber completed'
		end
	end

	def qSatellite
		desc "Check RPM in satellite"
		task :querySatellite do
			logger.info 'Executing task querySatellite'
			begin
				katello_package_query = %W(hammer
				                    --output json
                                    --username #{@params[:KATELLO_LOGIN]}
									--password #{@params[:KATELLO_PASSWORD]}
                                    --server #{@params[:KATELLO_SERVER]}
                                  package list
                                    --organization #{@params[:KATELLO_ORGANIZATION]}
                                    --product #{@params[:KATELLO_PRODUCT]}
                                    --repository "#{@params[:KATELLO_REPOSITORY]}")

				katello_packages = JSON.parse(shlog(katello_package_query.join(" ")), :symbolize_names => true)

				katello_packages.each do |katello_package|
					logger.info "ID: #{katello_package[:ID]}, Filename: #{katello_package[:Filename]}"
					katello_package_name = katello_package[:Filename]
					if katello_package_name == @pkgname
						logger.error "#{katello_package_name} already exists in Katello product #{@params[:KATELLO_PRODUCT]}"
						raise RuntimeError
					end
					
				end
			rescue => boom
				logger.error "failed to query satellite: #{boom}"
				raise
			end
			logger.info 'Task querySatellite completed'
		end
	end		
		# begin
		#   @client = XMLRPC::Client.new2("#{@params[:SATELLITE_URL]}")
		#   @key = @client.call('auth.login', "#{@params[:SATELLITE_LOGIN]}", "#{@params[:SATELLITE_PASSWORD]}")
		#   @pkgs = @client.call('channel.software.listAllPackages', @key, "#{@params[:SATTELITE_CHANNELLABEL]}")
		# rescue => boom
		#   logger.error "Unable to connect to satellite: #{boom}. "
		#   raise
		# ensure 
		#   @client.call('auth.logout', @key)
		# end
		# logger.info "Checking for packages in channel #{@params[:SATTELITE_CHANNELLABEL]}"
		# @pkgs.each do |pkg|
		#   logger.info "#{pkg['name']}-#{pkg['version']}-#{pkg['release']}"
		#   if pkg['name'] == @name
		#     @pkgExist = 1
		#     if pkg['version'] == @fpmparams[:version].to_s
		#       @verExist = 1
		#       if pkg['release'] == @fpmparams[:iteration].to_s
		#         @rlsExist = 1
		#       end
		#     end
		#   end
		# end
		# if @rlsExist
		#   logger.error "#{@name}-#{@fpmparams[:version]}-#{@fpmparams[:iteration]} already exists in software channel #{@params[:SATTELITE_CHANNELLABEL]}"
		#   raise RuntimeError
		# elsif @verExist
		#   logger.info "Package #{@name} found #{@params[:SATTELITE_CHANNELLABEL]} software channel with same version #{@fpmparams[:version]} but different release"
		# elsif @pkgExist
		#   logger.info "Package #{@name} found #{@params[:SATTELITE_CHANNELLABEL]} software channel with different version (#{@fpmparams[:version]})"
		# else
		#   logger.info "Package #{@name} not found in software channel #{@params[:SATTELITE_CHANNELLABEL]}"
		# end

	def uploadRpmSatellite
		desc "Upload RPM in satellite"
		task :uploadToSatellite do
			logger.info 'Executing task uploadRpmSatellite'
			begin
        		katello_repository_find = %W(hammer
                                       --output json
                                       --username #{@params[:KATELLO_LOGIN]}
                                       --password #{@params[:KATELLO_PASSWORD]}
                                       --server #{@params[:KATELLO_SERVER]}
                                    repository list
                                       --search "#{@params[:KATELLO_REPOSITORY]}"
                                       --organization #{@params[:KATELLO_ORGANIZATION]}
                                       --product #{@params[:KATELLO_PRODUCT]})


				katello_repository = JSON.parse(shlog(katello_repository_find.join(" ")), :symbolize_names => true)

	  		rescue => boom
				logger.error "failed to search Katello: #{boom}"
				raise
			end

			begin
				katello_package_upload = %W(hammer
				                      --output json
                                      --username #{@params[:KATELLO_LOGIN]}
                                      --password #{@params[:KATELLO_PASSWORD]}
                                      --server #{@params[:KATELLO_SERVER]}
                                    repository upload-content
                                      --path #{@fpmparams[:rpm_output_dir]}#{@pkgname}
                                      --id #{katello_repository[0][:Id]})
				katello_upload = JSON.parse(shlog(katello_package_upload.join(" ")), :symbolize_names => true)
				logger.info katello_upload[:message]

			rescue => boom
				logger.error "failed to push to Katello: #{boom}"
				raise
			end
			logger.info 'Task uploadRpmSatellite completed'
		end
	end

	def buildRpm
		desc "Build RPM: #{@pkgname}"
		task :buildRpm, [:keep_tmp_file] do |t, args|
			logger.info 'Executing task buildRpm'
			unless @rlsExist
				@rpmsign = "--rpm-sign" if @params[:rpm_sign]
				if RPM_PLATFORMS.include? ohai[:platform]
					begin
						@tmpdir = `mktemp -d`.chomp
						logger.info "Creating #{@tmpdir} to build rpm."
						ln_sf "#{pwd}/#{@name}/input/contents", "#{@tmpdir}", :verbose => false
						logger.info "Building RPM '#{@pkgname}'"
						runFpm
					rescue
						logger.error "Failed to build package #{@fpmparams[:rpm_output_dir]}#{@pkgname}"
						raise
						ensure
						unless args[:keep_tmp_file] == "1"
							logger.info "removing #{@tmpdir}"
							remove_entry_secure "#{@tmpdir}"
						end
					end
				else
					logger.error "Not building RPM, platform [#{ohai[:platform]}] is not supported"
				end
			end
			logger.info 'Task buildRpm completed'	
		end
	end
end

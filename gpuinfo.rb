module GPU
		#Information about the GPU
	class AMDCard
		attr_accessor :monitor_files, :cards
		
		public
		#Initialize the new AMD GPU object
		def initialize
			#puts "Initializing..."
			#Hardware monitor directory
			mon_dir = '/sys/class/hwmon'
			
			#Hash to store each GPU
			@monitor_files = {}
			
			#Get the directories for possible graphics cards
			cards = (`ls #{mon_dir}`.split(/($|\n)/).reject {|x| x !~ /^hwmon/})
			cards.each do |dir|
				dir = dir.gsub(/[\s]*/, '') #Strip off any whitespace
				f = File.open("#{mon_dir}/#{dir}/name") #Get the hardware name
				name = f.gets.chomp
				f.close
				if name == 'amdgpu' #Only accept GPU types -- the others are usually CPUs
				then
					#Directory tree
					directories = {
						'root' => "#{mon_dir}/#{dir}",
						'device' => "#{mon_dir}/#{dir}/device"
					}
					
					#Pulse (PWM -- Pulse Width Modulation) files also
					#offer fan speeds -> fan[#]_input -- as variable inputs may
					#be available, this can't be effectively handled in the hash
					pulse_files = {
						'dir' => directories['root'],
						
						'pulse_control' => 'pwm1_enable', #0 for DC, 1 for manual, 2 for auto
						'pulse_setting' => 'pwm1', #Current pulse setting -- write for manual
						'pulse_max' => 'pwm1_max' #The maximum pulse setting -- usually 255
					}
					
					#Electrical data (Watts -- measured in microwatts 
					#for some reason, millivolts)
					power_files = {
						'dir' => directories['root'],
						
						'avg_power' => 'power1_average',
						'max_power' => 'power1_cap_max',
						'current_mv' => 'in0_input'
					}
					
					#Temperature, not temporary
					temp_files = {
						'dir' => directories['root'],
						
						'current_temp' => 'temp1_input', #Current temp
						'critical_temp' => 'temp1_crit' #Critical temps
					}
					
					#Files for reading and setting clock data
					clock_files = {
						'dir' => directories['device'], #Located in the device subfolder
						
						'gpu_force' => 'power_dpm_force_performance_level', #The user's chosen clocking method
						'gpu_clock' => 'pp_dpm_sclk', #GPU clock setting
						'vram_clock' => 'pp_dpm_mclk', #VRAM clock setting
						'gpu_percent' => 'gpu_busy_percent' #Percent GPU usage
					}
					
					#Each card's filesystem structure
					@monitor_files[dir] = {
						'dir_list' => directories, #Dir list
						
						'pulse_files' => pulse_files, #PWM files
						'power_files' => power_files, #Files with power (electrical) data
						'temp_files' => temp_files, #Temperature
						'clock_files' => clock_files #Clocking speeds
					}
				end
			end
			@cards = self.retrieve
		end
		#End initialization
		
		#Retrieve GPU data
		def retrieve
			cards = {}
			@monitor_files.each do |k,v|
				glxinfo = `glxinfo -B|grep "Device"`
				out = {'hwmon_id' => k}
				out['card_name'] = glxinfo.match(/(?<=: )[\s\w\d]+(?=[\s]+\()/)[0].chomp
				out['driver_info'] = glxinfo.match(/(?<=\()[^\(]+(?=\))/)[0].chomp
				
				out['pulse_max'] = File.read("#{v.dig('pulse_files', 'dir')}/#{v.dig('pulse_files', 'pulse_max')}").chomp
				
				out['max_power'] = (File.read("#{v.dig('power_files', 'dir')}/#{v.dig('power_files', 'max_power')}").chomp.to_f / (10 ** 6)).round 2
				
				out['critical_temp'] = (File.read("#{v.dig('temp_files', 'dir')}/#{v.dig('temp_files', 'critical_temp')}").chomp.to_f / (10 ** 3)).round 2
				
				
				out['dir_list'] = v['dir_list']
				out['temp_files'] = v['temp_files']
				out['pulse_files'] = v['pulse_files']
				out['power_files'] = v['power_files']
				out['clock_files'] = v['clock_files']

				cards[k.to_s] = out
			end
			cards
		end
		#End retrieval
		
		#Update the cards
		def update
			cards = {}
			#puts @cards
			@cards.each do |k,v|
				card = @cards[k]
				
				card['gpu_force'] = File.read("#{v.dig('clock_files', 'dir')}/#{v.dig('clock_files', 'gpu_force')}").chomp
				card['gpu_clock'] = (File.read("#{v.dig('clock_files', 'dir')}/#{v.dig('clock_files', 'gpu_clock')}").split(/$/).delete_if {|item| 
					!item.match?(/\*/)}).each {|item| item.gsub!(/([\d]+:[\s]+|[^\d])/i, '')}
				card['vram_clock'] = (File.read("#{v.dig('clock_files', 'dir')}/#{v.dig('clock_files', 'vram_clock')}").split(/$/).delete_if {|item| 
					!item.match?(/\*/)}).each {|item| item.gsub!(/([\d]+:[\s]+|[^\d])/i, '')}
				card['pulse_setting'] = File.read("#{v.dig('pulse_files', 'dir')}/#{v.dig('pulse_files', 'pulse_setting')}").chomp
				card['gpu_percent'] = File.read("#{v.dig('clock_files', 'dir')}/#{v.dig('clock_files', 'gpu_percent')}").chomp
				card['pulse_control'] = File.read("#{v.dig('pulse_files', 'dir')}/#{v.dig('pulse_files', 'pulse_control')}").chomp
				card['avg_power'] = (File.read("#{v.dig('power_files', 'dir')}/#{v.dig('power_files', 'avg_power')}").chomp.to_f / (10 ** 6)).round 2
				card['current_mv'] = File.read("#{v.dig('power_files', 'dir')}/#{v.dig('power_files', 'current_mv')}").chomp.to_f.round 2
				card['current_temp'] = (File.read("#{v.dig('temp_files', 'dir')}/#{v.dig('temp_files', 'current_temp')}").chomp.to_f / (10 ** 3)).round 2
			end
			@cards
		end
		#End update function
		
		#Get the GPU stats
		def info
			cards = self.update
			ret = {}
			
			cards.each do |card,data|
				out = {}
				out['hwmon_id'] = data['hwmon_id']
				out['name'] = data['card_name']
				out['driver'] = data['driver_info']
				out['max_power'] = data['max_power']
				out['gpu_state'] = data['gpu_force']
				out['gpu_clock'] = data['gpu_clock']
				out['vram_clock'] = data['vram_clock']
				out['pulse_control'] = data['pulse_control']
				
				ret[card] = out
			end
			ret
		end
		#End stats
		
		#Get GPU usage
		def usage
			cards = self.update
			ret = {}
			
			cards.each do |card,data|
				ret[card] = {
					'pulse_max' => File.read("#{@monitor_files.dig(card, 'pulse_files', 'dir')}/#{@monitor_files.dig(card, 'pulse_files', 'pulse_max')}").chomp,
					'pulse_setting' => data['pulse_setting'],
					'gpu_percent' => data['gpu_percent'],
					'curr_power' => (File.read("#{@monitor_files.dig(card, 'power_files', 'dir')}/#{@monitor_files.dig(card, 'power_files', 'avg_power')}").to_i / (10 ** 6)),
					'curr_voltage' => File.read("#{@monitor_files.dig(card, 'power_files', 'dir')}/#{@monitor_files.dig(card, 'power_files', 'current_mv')}").chomp
				}
			end
			ret
		end
		#End GPU usage
		
		#Get GPU temp
		def temp
			cards = self.update
			ret = {}
			
			cards.each do |card,data|
				ret[card] = {
					'critical_temp' => (File.read("#{@monitor_files.dig(card, 'temp_files', 'dir')}/#{@monitor_files.dig(card, 'temp_files', 'critical_temp')}").to_f / 1000.0).round(2),
					'current_temp' => data['current_temp']
				}
			end
			ret
		end
		#End GPU temp
		
		#Get GPU fan speeds
		def fspeed speed_perc=0
			#puts "Changing fan speed: #{speed_perc}"
			cards = self.update
			ret = {}
			
			cards.each do |card,data|
				#puts "Fan speed updating..."
				#puts "Speed is: #{speed_perc.to_f} and pulse controller is: #{data['pulse_control']}"
				if speed_perc.to_f != 0 && data['pulse_control'].to_i != 1
					#puts "Updated fan speed"
					f = File.open("#{@monitor_files.dig(card, 'pulse_files', 'dir')}/#{@monitor_files.dig(card, 'pulse_files', 'pulse_control')}", "r+")
					f.puts '1'
				end
				
				#puts "Changing fan speed"
				max_sp = File.read("#{@monitor_files.dig(card, 'pulse_files', 'dir')}/#{@monitor_files.dig(card, 'pulse_files', 'pulse_max')}").to_i
				
				new_speed = ((speed_perc.to_f / 100.0) * max_sp).ceil
				f = File.open("#{@monitor_files.dig(card, 'pulse_files', 'dir')}/#{@monitor_files.dig(card, 'pulse_files', 'pulse_setting')}", "r+")
				
				fout = 0.8 * max_sp
				curr_speed = f.read.chomp
				
				#puts new_speed
				
				case
				when new_speed == 0
					fout = curr_speed.to_f
				when new_speed < 0 && ((curr_speed.to_f + new_speed.to_f) < (0.6 * max_sp).ceil)
					fout = (0.6 * max_sp).ceil
				when new_speed > 0 && ((curr_speed.to_f + new_speed.to_f) > (0.95 * max_sp).ceil)
					fout = (0.95 * max_sp).floor
				else
					fout = ((curr_speed.to_f + new_speed.to_f).ceil).to_i
				end
				f.puts "#{fout}"
				#puts "Changing speed to: #{fout}"
				
				out = {}
				speeds = Dir.entries(data.dig('dir_list', 'root')).collect {|x| 
					if x.match?(/fan[\d]+_input/) 
					then
						fan = File.read("#{data.dig('dir_list', 'root')}/#{x}").to_i
						fan
					end}
				out['fan_speeds'] = speeds.reject {|x| x.nil?}
				ret[card] = out
			end
			#puts ret
			ret
		end
		#End fan speeds
		
		#Set the GPU clock speeds
		def cspeed speed=nil
			cards = self.update
			ret = {}
			
			cards.each do |card,data|
				speed.downcase!
				speed.strip!
				#puts "{Speed is: '#{speed}'}"
				
				power_states = (File.read("#{@monitor_files.dig(card, 'clock_files', 'dir')}/#{@monitor_files.dig(card, 'clock_files', 'gpu_clock')}").split(/$/).each {|x| x.chomp!}).reject {|x|
					x.strip!
				    x.gsub!(/(^.*:[\s]+|[\D]+$)/, '')
					x.nil? || x == ''
				}
				
				if speed == 'auto'
					f = File.open("#{@monitor_files.dig(card, 'clock_files', 'dir')}/#{@monitor_files.dig(card, 'clock_files', 'gpu_force')}", "r+")
					f.puts 'auto'
					f.close
				else
					f = File.open("#{@monitor_files.dig(card, 'clock_files', 'dir')}/#{@monitor_files.dig(card, 'clock_files', 'gpu_force')}", "r+")
					f.puts 'manual'
					f.close
					
					f = File.open("#{@monitor_files.dig(card, 'clock_files', 'dir')}/#{@monitor_files.dig(card, 'clock_files', 'gpu_clock')}", "r+")
					pcount = power_states.length
					
					index = 0
					
					arr = f.each.with_index do |l, i|
						if l.match?(/\*/)
							index = i
							break
						end
					end
					
					#puts "Index is: #{index}"
					
					#puts "Speed is: '#{speed}'. States count to #{pcount}"
					
					case
					when speed.match(/^-?[\d]+$/) then
						case
						when speed.to_i > (pcount - 1) then
							f.puts (pcount - 1)
							#puts "too high"
						when speed.to_i < 0 then
							f.puts 0
							#puts "too low"
						else
							f.puts speed.to_i
							#puts "just right"
						end
					when ['next', 'up'].include?(speed) then
						f.puts ((index < (pcount - 1)) ? (index + 1) : (pcount - 1))
					when ['last', 'down'].include?(speed) then
						f.puts ((index > 0) ? (index - 1) : 0)
					when speed == 'min' then
						f.puts 0
					when speed == 'max' then
						f.puts (pcount - 1)
					else
						#puts "Invalid input: #{speed}"
						f.puts index
					end
					f.close
				end
				#puts "#{power_states}"
			end
		end #End cspeed
	end #End class
end #End module

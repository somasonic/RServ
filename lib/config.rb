require 'yaml'

module RServ


  # Config class. Just a hash, really. Usage:
  # config = Config.new('conf/testconf.yaml')
  # config['value'] = "Just use it like a hash."
  #
  # It autosaves.
class Config
  def initialize(file)
    @file = file
		@config = Hash.new
    if File.exists?(@file)
      begin
        @config = YAML.load_file(@file)
        unless @config.class == Hash
          $log.warn("Config file #{@file} was corrupt. Config has dumped to #{@file}.old and new config has been created.")
          FileUtils.mv(@file, "#{@file}.old")
          @config = Hash.new
        end
      rescue
        $log.error("Couldn't load config file #{@file}.")
      end
    end
  end

  def [](key)
    @config[key]
  end

  def []=(key, value)
    @config[key] = value
    save
  end

  def load(file = @file)
    begin
      @config = YAML.load_file(file)
      true
    rescue
      $log.error("Couldn't rehash config file #{file}.")
    end
  end

  private

  def save(file = @file)
    begin
      File.open(file, 'w') do |out|
        YAML::dump(@config, out)
      end
    rescue
      $log.error("Couldn't save config file #{file}.")
    end
  end
end

end

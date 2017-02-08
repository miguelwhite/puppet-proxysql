require File.expand_path(File.join(File.dirname(__FILE__), '..', 'proxysql'))
Puppet::Type.type(:proxy_mysql_query_rule).provide(:proxysql, parent: Puppet::Provider::Proxysql) do
  desc 'Manage query rule for a ProxySQL instance.'
  commands mysql: 'mysql'

  # Build a property_hash containing all the discovered information about query rules.
  def self.instances
    instances = []
    rules = mysql([defaults_file, '-NBe',
                   'SELECT `rule_id` FROM `mysql_query_rules`'].compact).split("\n")

    # To reduce the number of calls to MySQL we collect all the properties in
    # one big swoop.
    rules.map do |rule_id|
      query = 'SELECT `active`, `username`, `schemaname`, `flagIN`, `flagOUT`, `apply`, '
      query << ' `client_addr`, `proxy_addr`, `proxy_port`, `destination_hostgroup`, '
      query << ' `digest`, `match_digest`, `match_pattern`, `negate_match_pattern`, `replace_pattern`, '
      query << ' `cache_ttl`, `reconnect`, `timeout`, `retries`, `delay`, `error_msg`, `log`, `comment`, '
      query << ' `mirror_flagOUT`, `mirror_hostgroup`'
      query << " FROM `mysql_query_rules` WHERE rule_id = '#{rule_id}'"

      @active, @username, @schemaname, @flag_in, @flag_out, @apply,
      @client_addr, @proxy_addr, @proxy_port, @destination_hostgroup,
      @digest, @match_digest, @match_pattern, @negate_match_pattern, @replace_pattern,
      @cache_ttl, @reconnect, @timeout, @retries, @delay, @error_msg, @log, @comment,
      @mirror_flag_out, @mirror_hostgroup = mysql([defaults_file, '-NBe', query].compact).split(%r{\s})
      name = "mysql_query_rule-#{rule_id}"

      instances << new(
        name: name,
        ensure: :present,
        rule_id: rule_id,
        active: @active,
        username: @username,
        schemaname: @schemaname,
        flag_in: @flag_in,
        flag_out: @flag_out,
        apply: @apply,
        client_addr: @client_addr,
        proxy_addr: @proxy_addr,
        proxy_port: @proxy_port,
        destination_hostgroup: @destination_hostgroup,
        digest: @digest,
        match_digest: @match_digest,
        match_pattern: @match_pattern,
        negate_match_pattern: @negate_match_pattern,
        replace_pattern: @replace_pattern,
        cache_ttl: @cache_ttl,
        reconnect: @reconnect,
        timeout: @timeout,
        retries: @retries,
        delay: @delay,
        error_msg: @error_msg,
        log: @log,
        comment: @comment,
        mirror_flag_out: @mirror_flag_out,
        mirror_hostgroup: @mirror_hostgroup
      )
    end
    instances
  end

  # We iterate over each proxy_mysql_query_rule entry in the catalog and compare it against
  # the contents of the property_hash generated by self.instances
  def self.prefetch(resources)
    rules = instances
    resources.keys.each do |name|
      provider = rules.find { |rule| rule.name == name }
      resources[name].provider = provider if provider
    end
  end

  def create
    _name = @resource[:name]
    rule_id = make_sql_value(@resource.value(:rule_id))
    active = make_sql_value(@resource.value(:active) || 0)
    username = make_sql_value(@resource.value(:username) || nil)
    schemaname = make_sql_value(@resource.value(:schemaname) || nil)
    flag_in = make_sql_value(@resource.value(:flag_in) || 0)
    flag_out = make_sql_value(@resource.value(:flag_out) || nil)
    apply = make_sql_value(@resource.value(:apply) || 0)
    client_addr = make_sql_value(@resource.value(:client_addr) || nil)
    proxy_addr = make_sql_value(@resource.value(:proxy_addr) || nil)
    proxy_port = make_sql_value(@resource.value(:proxy_port) || nil)
    destination_hostgroup = make_sql_value(@resource.value(:destination_hostgroup) || nil)
    digest = make_sql_value(@resource.value(:digest) || nil)
    match_digest = make_sql_value(@resource.value(:match_digest) || nil)
    match_pattern = make_sql_value(@resource.value(:match_pattern) || nil)
    negate_match_pattern = make_sql_value(@resource.value(:negate_match_pattern) || 0)
    replace_pattern = make_sql_value(@resource.value(:replace_pattern) || nil)
    cache_ttl = make_sql_value(@resource.value(:cache_ttl) || nil)
    reconnect = make_sql_value(@resource.value(:reconnect) || nil)
    timeout = make_sql_value(@resource.value(:timeout) || nil)
    retries = make_sql_value(@resource.value(:retries) || nil)
    delay = make_sql_value(@resource.value(:delay) || nil)
    error_msg = make_sql_value(@resource.value(:error_msg) || nil)
    log = make_sql_value(@resource.value(:log) || nil)
    comment = make_sql_value(@resource.value(:comment) || nil)
    mirror_flag_out = make_sql_value(@resource.value(:mirror_flag_out) || nil)
    mirror_hostgroup = make_sql_value(@resource.value(:mirror_hostgroup) || nil)

    query = 'INSERT INTO `mysql_query_rules` ('
    query << '`rule_id`, `active`, `username`, `schemaname`, `flagIN`, `flagOUT`, `apply`, '
    query << '`client_addr`, `proxy_addr`, `proxy_port`, `destination_hostgroup`, '
    query << '`digest`, `match_digest`, `match_pattern`, `negate_match_pattern`, `replace_pattern`, '
    query << '`cache_ttl`, `reconnect`, `timeout`, `retries`, `delay`, `error_msg`, `log`, `comment`, '
    query << '`mirror_flagOUT`, `mirror_hostgroup`) VALUES ('
    query << "#{rule_id}, #{active}, #{username}, #{schemaname}, #{flag_in}, #{flag_out}, #{apply}, "
    query << "#{client_addr}, #{proxy_addr}, #{proxy_port}, #{destination_hostgroup}, "
    query << "#{digest}, #{match_digest}, #{match_pattern}, #{negate_match_pattern}, #{replace_pattern}, "
    query << "#{cache_ttl}, #{reconnect}, #{timeout}, #{retries}, #{delay}, #{error_msg}, #{log}, #{comment}, "
    query << "#{mirror_flag_out}, #{mirror_hostgroup})"
    mysql([defaults_file, '-e', query].compact)
    @property_hash[:ensure] = :present

    exists? ? (return true) : (return false)
  end

  def destroy
    rule_id = @resource.value(:rule_id)
    mysql([defaults_file, '-e', "DELETE FROM `mysql_query_rules` WHERE `rule_id` = '#{rule_id}'"].compact)

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def flush
    update_query_rule(@property_flush) if @property_flush
    @property_hash.clear

    load_to_runtime = @resource[:load_to_runtime]
    mysql([defaults_file, '-NBe', 'LOAD MYSQL QUERY RULES TO RUNTIME'].compact) if load_to_runtime == :true

    save_to_disk = @resource[:save_to_disk]
    mysql([defaults_file, '-NBe', 'SAVE MYSQL QUERY RULES TO DISK'].compact) if save_to_disk == :true

  end

  def update_query_rule(properties)
    rule_id = @resource.value(:rule_id)

    return false if properties.empty?

    values = []
    properties.each do |field, value|
      sql_value = make_sql_value(value)
      values.push("`#{field}` = #{sql_value}")
    end

    query = 'UPDATE `mysql_query_rules` SET '
    query << values.join(', ')
    query << " WHERE `rule_id` = '#{rule_id}'"

    mysql([defaults_file, '-e', query].compact)
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def active=(value)
    @property_flush[:active] = value
  end

  def username=(value)
    @property_flush[:username] = value
  end

  def schemaname=(value)
    @property_flush[:schemaname] = value
  end

  def flag_in=(value)
    @property_flush[:flag_in] = value
  end

  def flag_out=(value)
    @property_flush[:flag_out] = value
  end

  def apply=(value)
    @property_flush[:apply] = value
  end

  def client_addr=(value)
    @property_flush[:client_addr] = value
  end

  def proxy_addr=(value)
    @property_flush[:proxy_addr] = value
  end

  def proxy_port=(value)
    @property_flush[:proxy_port] = value
  end

  def destination_hostgroup=(value)
    @property_flush[:destination_hostgroup] = value
  end

  def digest=(value)
    @property_flush[:digest] = value
  end

  def match_digest=(value)
    @property_flush[:match_digest] = value
  end

  def match_pattern=(value)
    @property_flush[:match_pattern] = value
  end

  def negate_match_pattern=(value)
    @property_flush[:negate_match_pattern] = value
  end

  def replace_pattern=(value)
    @property_flush[:replace_pattern] = value
  end

  def cache_ttl=(value)
    @property_flush[:cache_ttl] = value
  end

  def reconnect=(value)
    @property_flush[:reconnect] = value
  end

  def timeout=(value)
    @property_flush[:timeout] = value
  end

  def retries=(value)
    @property_flush[:retries] = value
  end

  def delay=(value)
    @property_flush[:delay] = value
  end

  def error_msg=(value)
    @property_flush[:error_msg] = value
  end

  def log=(value)
    @property_flush[:log] = value
  end

  def comment=(value)
    @property_flush[:comment] = value
  end

  def mirror_flag_out=(value)
    @property_flush[:mirror_flag_out] = value
  end

  def mirror_hostgroup=(value)
    @property_flush[:mirror_hostgroup] = value
  end
end

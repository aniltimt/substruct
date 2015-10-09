# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_substruct_rel_1-3-1_session',
  :secret      => '8feda25171ddf3053527034ccebce4c078f7bda183185cbf4cf6eb3676b669f4f3dd86d10dde107595fe942f6a3ca284f46609a5566228619c37b1701997a42b'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store

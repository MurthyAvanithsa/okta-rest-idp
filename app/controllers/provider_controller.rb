require 'onelogin/ruby-saml'
require 'onelogin/ruby-saml/idp_metadata_parser'

class ProviderController < ApplicationController
  skip_before_action :verify_authenticity_token
  def initialize()
    @okta_client= Oktakit.new(token: "#{ENV.fetch('OKTA_API_TOKEN')}", organization: '#{ENV.fetch('OKTA_TENANT')}')
    @OKTA_IDP_POLICY_ID = "#{ENV.fetch('IDP_POLICY_ID')}
    # 00p469ih3xP9r843d5d6
    # @okta_client = Oktakit.new(token: "#{ENV.fetch('OKTA_API_TOKEN')}", api_endpoint: "#{ENV.fetch('AUTH_SAML')}/api/v1")
  end

  def index
    @title = "Products101"
  end
  def build_idp_payload(external_idp, kid_response)
    payload =  {
      'type' => 'SAML2',
      'name'=> external_idp["name"],
      'protocol'=> {
        'type'=> 'SAML2',
        'endpoints'=> {
          'sso'=> {
            'url'=> external_idp["sso_url"],
            'binding'=> 'HTTP-POST',
            'destination'=> external_idp["sso_url"]
          },
          'acs'=> {
            'binding'=> 'HTTP-POST',
            'type'=> 'INSTANCE'
          }
        },
        'algorithms'=> {
          'request'=> {
            'signature'=> {
              'algorithm'=> 'SHA-256',
              'scope'=> 'REQUEST'
            }
          },
          'response'=> {
            'signature'=> {
              'algorithm'=> 'SHA-256',
              'scope'=> 'ANY'
            }
          }
        },
        'credentials'=> {
          'trust'=> {
            'issuer'=> external_idp["issuer"],
            'audience'=> external_idp["audience"],
            'kid'=> kid_response[:kid]
          }
        }
      },
      'policy'=> {  
        'provisioning'=> {
          'action'=> 'DISABLED',
          'profileMaster'=> false,
          'groups'=> {
            'action'=> 'NONE'
          }
        },
        'accountLink'=> {
          'filter'=> nil,
          'action'=> 'AUTO'
        },
        'subject'=> {
          'userNameTemplate'=> {
            'template'=> 'idpuser.subjectNameId'
          },
          'format'=> [
              'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
        ],
          'filter'=> '',
          'matchType'=> 'USERNAME'
        }
      }
    }
    return payload
  end

  def upload_cert(cert)
    begin
      okta_key = Hash.new
      x5c = [cert]
      okta_key['x5c'] = x5c
      response, status = @okta_client.post("/idps/credentials/keys", okta_key)
      puts "keys post status #{status}"
      if status == 409
        existing_kid = response[:errorSummary].match /(?<==).*/
        return {:kid => existing_kid.to_s.gsub('.' , '') }, true
      end
      rescue StandardError => error
        if error.class == Oktakit::Conflict
          existing_kid = error.message.match /(?<==).*/
          return {:kid => existing_kid.to_s.gsub('.' , '') }, true
        end
        Rails.logger.error(error)
        throw error
     
      return response, status
    end
  end

    
  def get_routing_rule_payload(idp_name, idp_id, domains)
    payload = {
      'type' => 'IDP_DISCOVERY',
      'name' => "#{idp_name} routing rule",
      'priority' => 1,
      'conditions' => {
        'userIdentifier' => {
          'patterns' => [
          ],
      'type' => 'IDENTIFIER'
      }
      },
    'actions' => {
        'idp' => {
          'providers' => [
            {
              'type' => 'SAML2',
              'id' => idp_id
          }
          ]
        }
      }
    }
    payload['conditions']['userIdentifier']['patterns'] = domains.map{|domain| {
        'matchType' => 'SUFFIX',
        'value' => domain
      }
    } 
  return payload
end

  def create_idp_rule(domains, idp_id, idp_name)
    begin
      routing_rule_payload = get_routing_rule_payload(idp_name, idp_id, domains)

      response, status = @okta_client.post("/policies/#{@OKTA_IDP_POLICY_ID}/rules", routing_rule_payload)
      rescue StandardError => error
        if error.class == Oktakit::Conflict
          existing_kid = error.message.match /(?<==).*/
          return {:kid => existing_kid.to_s.gsub('.' , '') }
        end
        Rails.logger.error(error)
        response = {"error":error}
        status = false
      return response, status
    end
  end

  def create_idp(external_idp)
    begin
      #upload cert or if cert already exists get the kid
      kid_response, status = upload_cert(external_idp["certificate"])
      Rails.logger.info( "upload_cert status #{status}")
      idp_payload = build_idp_payload(external_idp, kid_response)
     
      idp_response, status = @okta_client.post("/idps", idp_payload)
      Rails.logger.info "creare idps status #{status}"

      rule_response, status = create_idp_rule(external_idp["domains"], idp_response[:id], external_idp["name"])
      Rails.logger.info "creare idp rule status #{status} rule_response: #{rule_response.inspect}"

      return idp_response[:id], idp_response[:_links][:acs][:href] , rule_response[:id], true
      
      rescue StandardError => error
        Rails.logger.error(error)
        response = error
      return response, nil, nil, false
    end
  end


  def save
    file_data = params[:file]
    @idp_name = params[:name]
    domainString = params[:domains]
    @domains = domainString.split(',')
    if file_data.respond_to?(:read)
      @samlmeta_string = file_data.read
    elsif file_data.respond_to?(:path)
      samlmeta_string = File.read(file_data.path)
    else
      logger.error "Bad file_data: #{file_data.class.name}: #{file_data.inspect}"
    end

    idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new
    # settings = idp_metadata_parser.parse(samlmeta_string)
    @metadata = idp_metadata_parser.parse_to_hash(@samlmeta_string)

    external_idp = {
      "certificate" =>@metadata[:idp_cert], 
      "name"=>@idp_name, 
      "sso_url"=>@metadata[:idp_sso_target_url] ,
      "issuer"=>@metadata[:idp_entity_id],
      "audience"=>@metadata[:idp_entity_id],
      "domains"=>@domains,
    }
    okta_idp_id, acs_url, okta_rule_id, status = create_idp(external_idp)
    Rails.logger.info "create IDP status:#{status}, acr_url:#{acs_url} okta_rule_id#{okta_rule_id} okta_idp_id #{okta_idp_id}" 
    idp = IdentityProvider.new(name: external_idp[:name], sp_meta:  @samlmeta_string,idp_okta_id:okta_idp_id)
    idp.save
    all_idps = IdentityProvider.all

    all_idps.each do |idp|
      puts idp.inspect
    end

    render json: {external_idp: external_idp}, status: :ok
  end
end

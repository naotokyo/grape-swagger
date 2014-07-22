require 'spec_helper'

describe 'API Models' do

  before :all do
    module Entities
      class Something < Grape::Entity
        expose :text, documentation: { type: 'string', desc: 'Content of something.' }
      end
    end

    module Entities
      module Some
        class Thing < Grape::Entity
          expose :text, documentation: { type: 'string', desc: 'Content of something.' }
        end
      end
    end

    module Entities
      class ComposedOf < Grape::Entity
        expose :part_text, documentation: { type: 'string', desc: 'Content of composedof.' }
      end

      class ComposedOfElse < Grape::Entity
        def self.entity_name
          'composed'
        end
        expose :part_text, documentation: { type: 'string', desc: 'Content of composedof else.' }
      end

      class SomeThingElse < Grape::Entity
        expose :else_text, documentation: { type: 'string', desc: 'Content of something else.' }
        expose :parts, using: Entities::ComposedOf, documentation: { type: 'ComposedOf',
                                                                     is_array: true,
                                                                     required: true }

        expose :part, using: Entities::ComposedOfElse, documentation: { type: 'composes' }
      end
    end
  end

  def app
    Class.new(Grape::API) do
      format :json
      desc 'This gets something.', entity: Entities::Something

      get '/something' do
        something = OpenStruct.new text: 'something'
        present something, with: Entities::Something
      end

      desc 'This gets thing.', entity: Entities::Some::Thing
      get '/thing' do
        thing = OpenStruct.new text: 'thing'
        present thing, with: Entities::Some::Thing
      end

      desc 'This gets somthing else.', entity: Entities::SomeThingElse
      get '/somethingelse' do
        part = OpenStruct.new part_text: 'part thing'
        thing = OpenStruct.new else_text: 'else thing', parts: [part], part: part

        present thing, with: Entities::SomeThingElse
      end

      add_swagger_documentation
    end
  end

  context 'swagger_doc' do
    subject do
      get '/swagger_doc'
      JSON.parse(last_response.body)
    end

    it 'returns a swagger-compatible doc' do
      expect(subject).to include(
        'apiVersion' => '0.1',
        'swaggerVersion' => '1.2',
        'info' => {},
        'produces' => ['application/json']
      )
    end

    it 'documents apis' do
      expect(subject['apis']).to eq [
        { 'path' => '/something.{format}', 'description' => 'Operations about somethings' },
        { 'path' => '/thing.{format}', 'description' => 'Operations about things' },
        { 'path' => '/somethingelse.{format}', 'description' => 'Operations about somethingelses' },
        { 'path' => '/swagger_doc.{format}', 'description' => 'Operations about swagger_docs' }
      ]
    end
  end

  it 'returns type' do
    get '/swagger_doc/something.json'
    result = JSON.parse(last_response.body)
    expect(result['apis'].first['operations'].first['type']).to eq 'Something'
  end

  it 'includes nested type' do
    get '/swagger_doc/thing.json'
    result = JSON.parse(last_response.body)
    expect(result['apis'].first['operations'].first['type']).to eq 'Some::Thing'
  end

  it 'includes entities which are only used as composition' do
    get '/swagger_doc/somethingelse.json'
    result = JSON.parse(last_response.body)
    expect(result['apis']).to eq([{
                                   'path' => '/somethingelse.{format}',
                                   'operations' => [{
                                     'notes' => '',
                                     'type' => 'SomeThingElse',
                                     'summary' => 'This gets somthing else.',
                                     'nickname' => 'GET-somethingelse---format-',
                                     'method' => 'GET',
                                     'parameters' => []
                                   }]
                                 }])

    expect(result['models']['SomeThingElse']).to include('id' => 'SomeThingElse',
                                                         'properties' => {
                                                           'else_text' => {
                                                             'type' => 'string',
                                                             'description' => 'Content of something else.'
                                                           },
                                                           'parts' => {
                                                             'type' => 'array',
                                                             'items' => { '$ref' => 'ComposedOf' }
                                                           },
                                                           'part' => { '$ref' => 'composes' }
                                                         },
                                                         'required' => ['parts']

                                                 )

    expect(result['models']['ComposedOf']).to include(
                                                        'id' => 'ComposedOf',
                                                        'properties' => {
                                                          'part_text' => {
                                                            'type' => 'string',
                                                            'description' => 'Content of composedof.'
                                                          }
                                                        }
                                                      )

    expect(result['models']['composed']).to include(
                                                      'id' => 'composed',
                                                      'properties' => {
                                                        'part_text' => {
                                                          'type' => 'string',
                                                          'description' => 'Content of composedof else.'
                                                        }

                                                      }
                                                    )
  end
end
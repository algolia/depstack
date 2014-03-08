# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140308032302) do

  create_table "dependencies", force: true do |t|
    t.integer "source_id",                 null: false
    t.integer "destination_id",            null: false
    t.integer "environment_cd"
    t.string  "requirement",    limit: 32
  end

  add_index "dependencies", ["destination_id"], name: "index_dependencies_on_destination_id"
  add_index "dependencies", ["source_id", "destination_id"], name: "index_dependencies_on_source_id_and_destination_id"
  add_index "dependencies", ["source_id"], name: "index_dependencies_on_source_id"

  create_table "libraries", force: true do |t|
    t.integer "manager_cd",                              null: false
    t.string  "name",                                    null: false
    t.string  "platform",       limit: 16
    t.text    "description",    limit: 8192
    t.integer "downloads"
    t.string  "homepage_uri"
    t.string  "repository_uri"
    t.integer "votes_count",                 default: 0, null: false
  end

  add_index "libraries", ["manager_cd", "name"], name: "index_libraries_on_manager_cd_and_name"

  create_table "users", force: true do |t|
    t.string   "login",      null: false
    t.string   "email"
    t.string   "name"
    t.string   "avatar_url"
    t.datetime "created_at", null: false
  end

  create_table "votes", force: true do |t|
    t.integer  "user_id",    null: false
    t.integer  "library_id", null: false
    t.datetime "created_at", null: false
  end

  add_index "votes", ["library_id"], name: "index_votes_on_library_id"
  add_index "votes", ["user_id", "library_id"], name: "index_votes_on_user_id_and_library_id"
  add_index "votes", ["user_id"], name: "index_votes_on_user_id"

end

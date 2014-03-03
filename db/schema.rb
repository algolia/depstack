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

ActiveRecord::Schema.define(version: 20140302191829) do

  create_table "dependencies", force: true do |t|
    t.integer "project_id",             null: false
    t.integer "library_id",             null: false
    t.string  "environment", limit: 16
    t.string  "requirement", limit: 16
  end

  add_index "dependencies", ["library_id"], name: "index_dependencies_on_library_id"
  add_index "dependencies", ["project_id", "library_id"], name: "index_dependencies_on_project_id_and_library_id"
  add_index "dependencies", ["project_id"], name: "index_dependencies_on_project_id"

  create_table "libraries", force: true do |t|
    t.string  "name",                    null: false
    t.string  "info"
    t.integer "downloads"
    t.string  "platform",     limit: 16
    t.string  "homepage_uri"
    t.text    "raw"
  end

  add_index "libraries", ["name"], name: "index_libraries_on_name"

  create_table "projects", force: true do |t|
    t.string   "user",                                      null: false
    t.string   "name",                                      null: false
    t.string   "description",                               null: false
    t.string   "language",           limit: 16
    t.integer  "fork_count",                    default: 0, null: false
    t.integer  "watcher_count",                 default: 0, null: false
    t.string   "dependency_manager"
    t.text     "dependencies"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "projects", ["user", "name"], name: "index_projects_on_user_and_name"

end

require "spec"
require "../src/lucky_record"
require "./support/*"

LuckyRecord::Repo.db_name = "lucky_record_test"

Spec.after_each do
  UserRows.new.destroy_all
end
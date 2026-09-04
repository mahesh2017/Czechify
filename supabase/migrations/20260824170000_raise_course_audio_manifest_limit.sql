-- The production audio manifest contains the full course catalogue and is
-- larger than the original one-megabyte bootstrap limit. Keep a modest cap
-- while allowing that non-personal manifest to be published with the audio.
update storage.buckets
set file_size_limit = 5242880
where id = 'course-audio';

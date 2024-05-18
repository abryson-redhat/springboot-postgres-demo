SELECT EXISTS (
   SELECT 1
   FROM pg_tables
   WHERE schemaname = 'petclinic'
   AND tablename = 'vets'
);

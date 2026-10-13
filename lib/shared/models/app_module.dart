/// Exactly four business destinations. Profile is a support route.
enum AppModule {
  community('/community'),
  recipes('/recipes'),
  cookToday('/cook-today'),
  shopping('/shopping');

  const AppModule(this.path);
  final String path;
}

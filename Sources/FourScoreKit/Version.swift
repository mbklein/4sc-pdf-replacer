/// The single source of truth for the project's version. The CLI reports it with
/// `--version`, and `scripts/build-app.sh` copies it into the app's Info.plist.
public enum FourScoreVersion {
    /// Semantic version (MAJOR.MINOR.PATCH). Keep this a plain string literal on one line;
    /// the build script reads it with sed.
    public static let string = "1.0.0"
}

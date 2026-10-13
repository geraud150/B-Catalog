/// Nom de la boutique Loyverse, tel qu'il apparaît dans les en-têtes des
/// colonnes spécifiques au magasin ("Available for sale [...]", "Price
/// [...]", etc.) du fichier d'import Loyverse. À modifier ici si le nom de
/// la boutique change.
const String kLoyverseStoreName = 'Top White Limited';

/// Devise affichée à côté des prix dans l'app (liste des produits, écran de
/// vérification...). À modifier ici si la boutique change de devise.
///
/// Le fichier d'export CSV Loyverse (voir features/export/) n'a pas besoin
/// de cette constante : Loyverse applique la devise déjà configurée sur la
/// boutique elle-même, seul le nombre est écrit dans le fichier.
const String kCurrencySymbol = 'FCFA';

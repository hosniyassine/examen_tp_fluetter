# Backend du TP7

Backend Spring Boot autonome utilisé pour connecter l'application Flutter existante à `http://10.0.2.2:8081` depuis l'émulateur Android. Il utilise le JDK local d'Android Studio, un fichier H2 local (`backend/data/tp7-db`) et BCrypt pour ne pas stocker les mots de passe en clair. Les données de la base et les journaux du serveur ne sont pas inclus dans Git.

## Lancer

Depuis ce dossier, avec JDK 25 installé, démarrez le serveur avec PowerShell :

```powershell
.\gradlew.bat bootRun
```

Le wrapper télécharge Gradle 9.3.1 si nécessaire. Le serveur écoute sur le port 8081 et toutes les interfaces pour l'émulateur. Les variables `SERVER_PORT`, `DB_URL`, `DB_USERNAME` et `DB_PASSWORD` peuvent les remplacer.

Les dépendances Gradle viennent de Maven Central. Pour tester :

```powershell
.\gradlew.bat test
```

Pour construire l'archive :

```powershell
.\gradlew.bat bootJar
```

## Contrat

Le PDF du TP confirme `POST /register` et `POST /login`, corps `{email,password}`. Le service retourne `{id,email}` sans mot de passe; les mots de passe sont hachés BCrypt.

Le PDF ne définit pas le CRUD REST. Pour rendre le client Flutter existant testable, ce backend implémente le contrat actuellement utilisé par `lib/api_service.dart` :

- `GET/POST /classes`, `PUT/DELETE /classes/{codClass}`
- `GET/POST /formations`, `PUT/DELETE /formations/{id}`
- `GET/POST /etudiants`, `PUT/DELETE /etudiants/{id}`

Les formes JSON suivent `lib/models.dart` et les associations du diagramme du sujet. C'est un choix d'implémentation destiné à être comparé au backend/contrat fourni par l'enseignant; ces routes CRUD ne sont pas garanties par le PDF. La base de données n'étant pas prescrite par le sujet, H2 fichier a été choisi pour permettre un démarrage local sans serveur SQL externe.

Ce backend utilise un jeton de session après connexion et applique les rôles aux routes API.

## Notes par période, rôles et migration H2

La mise à niveau utilise `spring.jpa.hibernate.ddl-auto=update`, comme la configuration existante. Elle ajoute les colonnes manquantes et les nouvelles tables sans supprimer ni renommer `note`, qui conserve les notes historiques sous la forme initiale. Les nouvelles saisies sont stockées séparément dans `note_evaluation`, avec une clé étudiant/matière/année universitaire/semestre. Les champs de note restent nuls tant qu'ils ne sont pas saisis. Le champ `matiere.has_tp` est nullable lors de la migration : configurez chaque ancienne matière avant d'y saisir des notes.

Les comptes disposent désormais du rôle `ADMIN`, `TEACHER` ou `STUDENT`. Les comptes existants sans rôle sont migrés comme administrateurs afin de préserver leur accès historique. Les nouvelles inscriptions sont des comptes étudiants sans association jusqu'à ce qu'un administrateur les lie à un étudiant. Les enseignants sont stockés dans `enseignant`; leurs matières et classes affectées sont stockées dans `enseignant_affectation`. Un compte administrateur initial peut être déclaré avec `BOOTSTRAP_ADMIN_EMAIL` avant son inscription. Les jetons de session sont en mémoire et perdus au redémarrage du backend; reconnectez-vous ensuite.

Les calculs suivent les formules TP 20 %, DS 30 %, examen 50 %, ou DS 30 %, examen 70 % sans TP. Les moyennes sont arrondies à deux décimales; une note obligatoire absente donne `EN_ATTENTE`, et la moyenne générale n'est fournie que lorsque toutes les matières de la classe pour la période sont complètes. Le seuil de validation est 10/20.

# Windora : allègement de Windows, lu par setup.ps1.
#
# Seulement des changements sans risque pour les jeux, Vanguard, WSL, Windows Update et la
# sécurité, tous annulables avec « setup.ps1 -Restore ».
# Volontairement ABSENTS (à faire soi-même si on le souhaite) : imprimante (Spooler),
# Bluetooth, localisation, Xbox / Game Pass / Game Bar, Teams, Outlook, Phone Link,
# indexation, SysMain, Hyper-V / isolation du noyau, Defender, mises à jour.
@{
    # Services : seuls ceux qui démarrent d'eux-mêmes comptent ; les services « manuels »
    # arrêtés ne consomment rien, les désactiver ne gagne rien.
    Services = @(
        @{ Name = 'DiagTrack';  StartType = 'Disabled'; Label = 'Télémétrie (Expériences des utilisateurs connectés)' }
        @{ Name = 'MapsBroker'; StartType = 'Manual';   Label = 'Gestionnaire de cartes téléchargées (au besoin seulement)' }
    )

    # Réglages pour tout l'ordinateur (stratégies).
    MachineRegistry = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 1; Kind = 'DWord'
           Label = 'Données de diagnostic au minimum (« requises »)' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0; Kind = 'DWord'
           Label = 'Widgets désactivés' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecallEnablement'; Value = 0; Kind = 'DWord'
           Label = 'Recall (captures d''écran par l''IA) retiré' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1; Kind = 'DWord'
           Label = 'Analyse IA de l''écran désactivée' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Edge ne se précharge plus au démarrage' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Edge ne tourne plus en arrière-plan une fois fermé' }
        @{ Path = 'Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings'
           Name = 'DownloadMode'; Value = 0; Kind = 'DWord'
           Label = 'Mises à jour : plus d''envoi vers d''autres PC sur Internet' }
    )

    # Tâches planifiées de collecte de données.
    Tasks = @(
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' }
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' }
        @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
        @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy' }
    )

    # Applications préinstallées retirées (réinstallables depuis le Microsoft Store).
    Apps = @(
        @{ Name = 'Microsoft.BingNews';                    Label = 'Actualités' }
        @{ Name = 'Microsoft.BingWeather';                 Label = 'Météo' }
        @{ Name = 'Microsoft.BingSearch';                  Label = 'Recherche Bing dans le menu Démarrer' }
        @{ Name = 'Microsoft.MicrosoftSolitaireCollection'; Label = 'Solitaire (avec publicités)' }
        @{ Name = 'Microsoft.Todos';                       Label = 'To Do' }
        @{ Name = 'Clipchamp.Clipchamp';                   Label = 'Clipchamp' }
        @{ Name = 'Microsoft.PowerAutomateDesktop';        Label = 'Power Automate' }
        @{ Name = 'Microsoft.WindowsFeedbackHub';          Label = 'Hub de commentaires' }
        @{ Name = 'Microsoft.MicrosoftOfficeHub';          Label = 'Microsoft 365 (raccourci publicitaire)' }
        @{ Name = 'Microsoft.Windows.DevHome';             Label = 'Dev Home (abandonné)' }
        @{ Name = 'Microsoft.Copilot';                     Label = 'Copilot' }
        @{ Name = 'Microsoft.Getstarted';                  Label = 'Astuces' }
        @{ Name = 'Microsoft.People';                      Label = 'Contacts' }
        @{ Name = 'Microsoft.549981C3F5F10';               Label = 'Cortana' }
    )

    # Réglages de ton compte : publicités, suggestions, recherche web, enregistrement en fond.
    UserRegistry = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Identifiant publicitaire désactivé' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Pas d''« expériences personnalisées »' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus d''applis installées en douce' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus de suggestions dans le menu Démarrer' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SoftLandingEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus d''astuces Windows' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus d''écran « bienvenue » après les mises à jour' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus d''applis suggérées' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus de conseils' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus de contenu suggéré dans les Paramètres (1/4)' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus de contenu suggéré dans les Paramètres (2/4)' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353696Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus de contenu suggéré dans les Paramètres (3/4)' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353698Enabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus de contenu suggéré dans les Paramètres (4/4)' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Value = 0; Kind = 'DWord'
           Label = 'Plus de recommandations dans le menu Démarrer' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_AccountNotifications'; Value = 0; Kind = 'DWord'
           Label = 'Plus de notifications de compte Microsoft dans Démarrer' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSyncProviderNotifications'; Value = 0; Kind = 'DWord'
           Label = 'Plus de pubs OneDrive dans l''Explorateur' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0; Kind = 'DWord'
           Label = 'Bouton Copilot masqué' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Plus d''écran « terminons la configuration de votre appareil »' }
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1; Kind = 'DWord'
           Label = 'Recherche Windows : plus de résultats web' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalCaptureEnabled'; Value = 0; Kind = 'DWord'
           Label = 'Pas d''enregistrement vidéo en continu pendant les jeux' }
        @{ Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0; Kind = 'DWord'
           Label = 'Plus de demandes d''avis' }
    )
}

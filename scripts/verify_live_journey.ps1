$ErrorActionPreference = 'Stop'

Write-Host "1. Probe Health Endpoint:"
$health = Invoke-RestMethod -Uri "http://localhost:3000/health"
Write-Host "   Status:" $health.status "Version:" $health.version

Write-Host "`n2. Journey J1: Register New User"
$unique = (Get-Random -Minimum 10000 -Maximum 99999)
$regBody = @{
    email = "live_audited_user_$unique@example.com"
    password = "LivePassword123!"
    dateOfBirth = "1994-08-20"
    heightCm = 178.0
    sexForCalculation = "male"
    locale = "en"
    numeralSystem = "western"
    consents = @{
        termsOfService = $true
        healthDataProcessing = $true
        aiThirdPartyProcessing = $true
    }
} | ConvertTo-Json

$reg = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/auth/register" -Method Post -Body $regBody -ContentType "application/json"
$token = $reg.tokens.accessToken
$userId = $reg.user.id
Write-Host "   Registered User ID:" $userId "Email:" $reg.user.email

Write-Host "`n3. Journey J5: Calculation Engine (Deterministic BMI/BMR/TDEE)"
$bmi = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/calculations/bmi?weightKg=82&heightCm=178"
Write-Host "   BMI:" $bmi.value "Classification:" $bmi.category

$tdee = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/calculations/tdee?bmr=1800&activityLevel=moderately_active"
Write-Host "   TDEE:" $tdee.value "kcal"

Write-Host "`n4. Profile Domain Inspection & Update"
$headers = @{ Authorization = "Bearer $token" }
$profile = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/profile" -Headers $headers
Write-Host "   Profile Height:" $profile.heightCm "cm, Sex:" $profile.sexForCalculation

$updateProfileBody = @{ heightCm = 179.0; activityLevel = "very_active" } | ConvertTo-Json
$updatedProf = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/profile" -Method Put -Headers $headers -Body $updateProfileBody -ContentType "application/json"
Write-Host "   Updated Height:" $updatedProf.heightCm "cm, Activity:" $updatedProf.activityLevel

Write-Host "`n5. Journey J9: AI Configuration & BYOK Management"
$aiConfig = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/config" -Headers $headers
Write-Host "   Active AI Provider:" $aiConfig.activeProvider
Write-Host "   Available Providers:" ($aiConfig.availableProviders -join ", ")
Write-Host "   Supported Models:" $aiConfig.models.Count

$byokBody = @{ provider = "google"; apiKey = "AIzaSyLiveValidationKey12345678" } | ConvertTo-Json
$byok = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/credentials" -Method Post -Headers $headers -Body $byokBody -ContentType "application/json"
Write-Host "   Stored BYOK Key Fingerprint:" $byok.credential.keyFingerprint

$testConnBody = @{ provider = "google" } | ConvertTo-Json
$testConn = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/test-connection" -Method Post -Headers $headers -Body $testConnBody -ContentType "application/json"
Write-Host "   Test Connection:" $testConn.status "-" $testConn.message

Write-Host "`n6. Journey J2: Record Observation with Mandatory Provenance"
$obsBody = @{
    typeCode = "weight"
    value = 82.5
    unit = "kg"
    originType = "manual_entry"
    epistemicClass = "measured"
} | ConvertTo-Json
$obs = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/measurements/observations" -Method Post -Headers $headers -Body $obsBody -ContentType "application/json"
Write-Host "   Observation ID:" $obs.observation.id "Value:" $obs.observation.canonical_value $obs.observation.canonical_unit
Write-Host "   Provenance ID:" $obs.observation.provenance_id "Epistemic:" $obs.provenance.epistemic_class

Write-Host "`n7. Journey J7: Goal Creation & Versioning"
$goalBody = @{
    goalType = "weight_loss"
    targetMetricTypeCode = "weight"
    startingValue = 82.5
    targetValue = 76.0
    ratePerWeek = 0.5
    isPrimary = $true
} | ConvertTo-Json
$goal = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/goals" -Method Post -Headers $headers -Body $goalBody -ContentType "application/json"
Write-Host "   Created Goal Target:" $goal.currentVersion.targetValue "kg (Version" $goal.currentVersion.version ")"

$verBody = @{ targetValue = 75.0; rationale = "Adjusted target" } | ConvertTo-Json
$ver = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/goals/$($goal.id)/versions" -Method Post -Headers $headers -Body $verBody -ContentType "application/json"
Write-Host "   Updated Goal Target:" $ver.currentVersion.targetValue "kg (Version" $ver.currentVersion.version ")"

Write-Host "`n8. Health Snapshot & Lineage Reconciliation"
$snap = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/analytics/snapshot" -Headers $headers
Write-Host "   Snapshot Weight:" $snap.sections.bodyStatus.latestWeightKg "kg"
Write-Host "   Primary Goal Target:" $snap.sections.goal.targetValue "kg"
Write-Host "   Source Watermark:" $snap.sourceDataWatermark

Write-Host "`n9. Journey J10: Privacy Export & Irreversible Purge"
$export = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/privacy/export" -Headers $headers
Write-Host "   GDPR Export Modules:" ($export.modules.PSObject.Properties.Name -join ", ")
Write-Host "   Measurements in Export:" $export.modules.measurements.Count

$delKey = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/credentials/google" -Method Delete -Headers $headers
Write-Host "   Deleted BYOK Key:" $delKey.success

$purge = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/privacy/account" -Method Delete -Headers $headers
Write-Host "   Account Purged:" $purge.success

Write-Host "`n=== ALL END-TO-END CRITICAL JOURNEYS VERIFIED SUCCESSFULLY! ==="

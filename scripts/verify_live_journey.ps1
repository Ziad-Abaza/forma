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

# Register OpenAI BYOK Key
$openaiBody = @{ provider = "openai"; apiKey = "sk-LiveValidationKeyOpenAI12345678" } | ConvertTo-Json
$openaiKey = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/credentials" -Method Post -Headers $headers -Body $openaiBody -ContentType "application/json"
Write-Host "   Stored OpenAI BYOK Key Fingerprint:" $openaiKey.credential.keyFingerprint

# Switch Active Provider to OpenAI
$switchPrefBody = @{ activeProvider = "openai" } | ConvertTo-Json
$prefRes = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/preferences" -Method Patch -Headers $headers -Body $switchPrefBody -ContentType "application/json"
Write-Host "   Switched Active Provider to:" $prefRes.activeProvider

$testConnBody = @{ provider = "openai" } | ConvertTo-Json
$testConn = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/test-connection" -Method Post -Headers $headers -Body $testConnBody -ContentType "application/json"
Write-Host "   Test Connection:" $testConn.status "-" $testConn.message

Write-Host "`n6. Journey J2: Record Observation with Mandatory Provenance & New Types"
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

# Test new measurement type: calf_circumference
$calfBody = @{
    typeCode = "calf_circumference"
    value = 38.5
    unit = "cm"
    originType = "manual_entry"
    epistemicClass = "measured"
} | ConvertTo-Json
$calfObs = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/measurements/observations" -Method Post -Headers $headers -Body $calfBody -ContentType "application/json"
Write-Host "   New Metric Observation (calf_circumference):" $calfObs.observation.canonical_value $calfObs.observation.canonical_unit

# Test Superseding Observation
$supersedeBody = @{
    newValue = 82.0
    newUnit = "kg"
    correctionReason = "Correction of scale calibration"
} | ConvertTo-Json
$supersededObs = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/measurements/observations/$($obs.observation.id)/supersede" -Method Post -Headers $headers -Body $supersedeBody -ContentType "application/json"
Write-Host "   Superseded Observation: New ID" $supersededObs.observation.id "Supersedes" $supersededObs.observation.superseded_observation_id

Write-Host "`n7. Journey J7: Goal Creation, Versioning & Status Lifecycle"
$goalBody = @{
    goalType = "weight_loss"
    targetMetricTypeCode = "weight"
    startingValue = 82.0
    targetValue = 76.0
    ratePerWeek = 0.5
    isPrimary = $true
} | ConvertTo-Json
$goal = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/goals" -Method Post -Headers $headers -Body $goalBody -ContentType "application/json"
Write-Host "   Created Goal Target:" $goal.currentVersion.targetValue "kg (Version" $goal.currentVersion.version ")"

$verBody = @{ targetValue = 75.0; rationale = "Adjusted target" } | ConvertTo-Json
$ver = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/goals/$($goal.id)/versions" -Method Post -Headers $headers -Body $verBody -ContentType "application/json"
Write-Host "   Updated Goal Target:" $ver.currentVersion.targetValue "kg (Version" $ver.currentVersion.version ")"

# Update Goal Status to Completed
$statusBody = @{ status = "completed"; rationale = "Target milestone reached" } | ConvertTo-Json
$statusRes = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/goals/$($goal.id)/status" -Method Patch -Headers $headers -Body $statusBody -ContentType "application/json"
Write-Host "   Goal Status Updated To:" $statusRes.goal.status

Write-Host "`n8. Health Snapshot & Lineage Reconciliation"
$snap = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/analytics/snapshot" -Headers $headers
Write-Host "   Snapshot Weight:" $snap.sections.bodyStatus.latestWeightKg "kg"
Write-Host "   Deterministic Macros - Protein:" $snap.sections.energy.macros.proteinGrams "g, Fat:" $snap.sections.energy.macros.fatGrams "g, Carbs:" $snap.sections.energy.macros.carbsGrams "g"
Write-Host "   Source Watermark:" $snap.sourceDataWatermark

Write-Host "`n9. Journey J10: Privacy Export & Irreversible Purge"
$export = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/privacy/export" -Headers $headers
Write-Host "   GDPR Export Modules:" ($export.modules.PSObject.Properties.Name -join ", ")
Write-Host "   Measurements in Export:" $export.modules.measurements.Count

$delKey = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/ai/credentials/openai" -Method Delete -Headers $headers
Write-Host "   Deleted BYOK Key:" $delKey.success

$purge = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/privacy/account" -Method Delete -Headers $headers
Write-Host "   Account Purged:" $purge.success

Write-Host "`n=== ALL END-TO-END CRITICAL JOURNEYS VERIFIED SUCCESSFULLY! ==="

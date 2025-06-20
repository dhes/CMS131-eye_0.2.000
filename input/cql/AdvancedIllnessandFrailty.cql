library AdvancedIllnessandFrailty version '1.23.001'

using QICore version '6.0.0'

include FHIRHelpers version '4.4.000' called FHIRHelpers
include QICoreCommon version '4.0.000' called QICoreCommon
include CumulativeMedicationDuration version '6.0.001' called CMD
include Status version '1.13.000' called Status 

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMEDCT": 'http://snomed.info/sct'

valueset "Advanced Illness": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.110.12.1082'
valueset "Dementia Medications": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.196.12.1510'
valueset "Frailty Device": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.118.12.1300'
valueset "Frailty Diagnosis": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.113.12.1074'
valueset "Frailty Encounter": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1088'
valueset "Frailty Symptom": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.113.12.1075'
 
code "Housing status": '71802-3' from "LOINC" display 'Housing status'
code "Lives in a nursing home (finding)": '160734000' from "SNOMEDCT" display 'Lives in a nursing home (finding)'
code "Medical equipment used": '98181-1' from "LOINC" display 'Medical equipment used'

parameter "Measurement Period" Interval<DateTime> default Interval[@2026-01-01T00:00:00, @2026-12-31T23:59:59]

context Patient

define "Is Age 66 or Older with Advanced Illness and Frailty":
   AgeInYearsAt(date from end of "Measurement Period")>= 66
    and "Has Criteria Indicating Frailty"
    and ( "Has Advanced Illness in Year Before or During Measurement Period"
        or "Has Dementia Medications in Year Before or During Measurement Period"
    )

define "Is Age 66 to 80 with Advanced Illness and Frailty or Is Age 81 or Older with Frailty":
  ( AgeInYearsAt(date from end of "Measurement Period")in Interval[66, 80]
      and "Has Criteria Indicating Frailty"
      and ( "Has Advanced Illness in Year Before or During Measurement Period"
          or "Has Dementia Medications in Year Before or During Measurement Period"
      )
  )
    or ( AgeInYearsAt(date from end of "Measurement Period")>= 81
        and "Has Criteria Indicating Frailty"
    )

define "Has Criteria Indicating Frailty":
  exists ( (([DeviceRequest: "Frailty Device"]).isDeviceOrder()) FrailtyDeviceOrder
      where FrailtyDeviceOrder.authoredOn.toInterval() during day of "Measurement Period"
  )
    or exists ( (([ObservationScreeningAssessment: "Medical equipment used"]).isAssessmentPerformed()) EquipmentUsed
        where EquipmentUsed.value as Concept in "Frailty Device" 
        and EquipmentUsed.effective.toInterval() ends during day of "Measurement Period"
    )
    or exists ( (([ConditionProblemsHealthConcerns: "Frailty Diagnosis"] P )
    union ([ConditionEncounterDiagnosis: "Frailty Diagnosis"] E )) FrailtyDiagnosis
        where FrailtyDiagnosis.prevalenceInterval() overlaps day of "Measurement Period"
    )
    or exists ( (([Encounter: "Frailty Encounter"]).isEncounterPerformed()) FrailtyEncounter
        where FrailtyEncounter.period.toInterval() overlaps day of "Measurement Period"
    )
    or exists ( (([SimpleObservation: "Frailty Symptom"]).isSymptom()) FrailtySymptom
        where FrailtySymptom.effective.toInterval() overlaps day of "Measurement Period"
    )

define "Has Advanced Illness in Year Before or During Measurement Period":
exists ((([ConditionProblemsHealthConcerns: "Advanced Illness"] P )
union ([ConditionEncounterDiagnosis: "Advanced Illness"] E )) AdvancedIllnessDiagnosis
where AdvancedIllnessDiagnosis.prevalenceInterval() starts during day of Interval[start of "Measurement Period" - 1 year, end of "Measurement Period"])

define "Has Dementia Medications in Year Before or During Measurement Period":
  exists (( ([MedicationRequest: medication in "Dementia Medications"]).isMedicationActive()) DementiaMedication
      where DementiaMedication.medicationRequestPeriod() overlaps day of Interval[start of "Measurement Period" - 1 year, 
        end of "Measurement Period"]
  )

define "Is Age 66 or Older Living Long Term in a Nursing Home":
  AgeInYearsAt(date from 
     end of "Measurement Period"
  )>= 66
    and ( ( Last( (([ObservationScreeningAssessment: "Housing status"]).isAssessmentPerformed()) HousingStatus    
          where HousingStatus.effective.toInterval() ends on or before 
          day of end of "Measurement Period"
          sort by 
          end of effective.toInterval() asc
      )) LastHousingStatus
        where LastHousingStatus.value ~ "Lives in a nursing home (finding)"
    ) is not null
import { BadRequestException, Injectable } from '@nestjs/common';
import { SyncSnapshot } from './sync.types';

@Injectable()
export class SyncSnapshotValidator {
  assertValid(snapshot: SyncSnapshot) {
    if (!snapshot || typeof snapshot !== 'object') {
      throw new BadRequestException('Snapshot body is required');
    }
    if (!snapshot.profile || typeof snapshot.profile !== 'object') {
      throw new BadRequestException('Snapshot profile is required');
    }
    if (!Array.isArray(snapshot.exercises)) {
      throw new BadRequestException('Snapshot exercises must be an array');
    }
    if (!Array.isArray(snapshot.trainingDays)) {
      throw new BadRequestException('Snapshot trainingDays must be an array');
    }
    if (!Array.isArray(snapshot.plannedExercises)) {
      throw new BadRequestException('Snapshot plannedExercises must be an array');
    }
    if (!Array.isArray(snapshot.sessions)) {
      throw new BadRequestException('Snapshot sessions must be an array');
    }
    if (!Array.isArray(snapshot.sets)) {
      throw new BadRequestException('Snapshot sets must be an array');
    }
    if (
      snapshot.progressPhotos !== undefined &&
      !Array.isArray(snapshot.progressPhotos)
    ) {
      throw new BadRequestException('Snapshot progressPhotos must be an array');
    }
  }
}

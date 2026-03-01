package model

import (
	"reflect"
	"testing"
)

func TestMergeUniqueInterleave(t *testing.T) {
	a := []int64{1, 2, 3, 4}
	b := []int64{3, 5, 6, 2}
	got := mergeUniqueInterleave(a, b, 6)
	want := []int64{1, 3, 2, 5, 6, 4}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected result, got=%v want=%v", got, want)
	}
}

func TestMixByRatio(t *testing.T) {
	personal := []int64{101, 102, 103, 104}
	global := []int64{201, 202, 203, 101, 204}
	got := mixByRatio(personal, global, 7, 2, 1)

	if len(got) != 7 {
		t.Fatalf("expected length 7, got %d", len(got))
	}

	seen := map[int64]struct{}{}
	for _, id := range got {
		if _, ok := seen[id]; ok {
			t.Fatalf("result should be unique, duplicate id=%d", id)
		}
		seen[id] = struct{}{}
	}
}

func TestAppendUnique(t *testing.T) {
	base := []int64{1, 2, 3}
	extras := []int64{3, 4, 5, 1, 6}
	got := appendUnique(base, extras, 5)
	want := []int64{1, 2, 3, 4, 5}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected result, got=%v want=%v", got, want)
	}
}

func TestDeterministicShuffle(t *testing.T) {
	ids := []int64{10, 20, 30, 40, 50}
	a := deterministicShuffle(ids, 20260215)
	b := deterministicShuffle(ids, 20260215)
	c := deterministicShuffle(ids, 20260216)

	if !reflect.DeepEqual(a, b) {
		t.Fatalf("same seed should produce same order, a=%v b=%v", a, b)
	}
	if reflect.DeepEqual(a, c) {
		t.Fatalf("different seeds should produce different order, a=%v c=%v", a, c)
	}
}
